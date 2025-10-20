#!/usr/bin/env python3
"""
Security Gate - Determines if build should pass or fail based on findings
"""

import argparse
import json
import sys
from pathlib import Path

class SecurityGate:
    def __init__(self, results_dir: Path, max_critical: int = 0, max_high: int = 5):
        self.results_dir = results_dir
        self.max_critical = max_critical
        self.max_high = max_high
    
    def load_checkov_results(self) -> dict:
        """Load Checkov results"""
        checkov_file = self.results_dir / "results_json.json"
        if not checkov_file.exists():
            print(f"❌ Checkov results not found: {checkov_file}")
            return {}
        
        with open(checkov_file, 'r') as f:
            return json.load(f)
    
    def categorize_severity(self, check_id: str) -> str:
        """Map check ID to severity"""
        if any(cid in check_id for cid in ['CKV_GCP_62', 'CKV_GCP_6', 'CKV_GCP_14']):
            return 'CRITICAL'
        elif 'CKV_GCP' in check_id or 'CKV_AWS' in check_id:
            return 'HIGH'
        elif 'CKV2' in check_id:
            return 'MEDIUM'
        else:
            return 'LOW'
    
    def evaluate(self) -> bool:
        """Evaluate if security gate passes"""
        print("=" * 60)
        print("Security Gate Evaluation")
        print("=" * 60)
        
        checkov_data = self.load_checkov_results()
        if not checkov_data:
            print("⚠️  No scan results found - failing by default")
            return False
        
        failed_checks = checkov_data.get('results', {}).get('failed_checks', [])
        
        # Count by severity
        severity_counts = {
            'CRITICAL': 0,
            'HIGH': 0,
            'MEDIUM': 0,
            'LOW': 0
        }
        
        for check in failed_checks:
            severity = self.categorize_severity(check.get('check_id', ''))
            severity_counts[severity] += 1
        
        print(f"\nFindings Summary:")
        print(f"  🔴 Critical: {severity_counts['CRITICAL']}")
        print(f"  🟠 High:     {severity_counts['HIGH']}")
        print(f"  🟡 Medium:   {severity_counts['MEDIUM']}")
        print(f"  ⚪ Low:      {severity_counts['LOW']}")
        
        print(f"\nSecurity Gate Policy:")
        print(f"  Maximum Critical: {self.max_critical}")
        print(f"  Maximum High:     {self.max_high}")
        
        # Evaluate
        passed = True
        reasons = []
        
        if severity_counts['CRITICAL'] > self.max_critical:
            passed = False
            reasons.append(
                f"Critical issues: {severity_counts['CRITICAL']} "
                f"(max allowed: {self.max_critical})"
            )
        
        if severity_counts['HIGH'] > self.max_high:
            passed = False
            reasons.append(
                f"High severity issues: {severity_counts['HIGH']} "
                f"(max allowed: {self.max_high})"
            )
        
        print("\n" + "=" * 60)
        if passed:
            print("✅ Security Gate: PASSED")
            print("=" * 60)
            print("\nThe code meets security requirements.")
            return True
        else:
            print("❌ Security Gate: FAILED")
            print("=" * 60)
            print("\nReasons for failure:")
            for reason in reasons:
                print(f"  - {reason}")
            print("\nPlease fix the security issues before merging.")
            return False

def main():
    parser = argparse.ArgumentParser(
        description="Security gate - fails build if security thresholds exceeded"
    )
    parser.add_argument(
        '--results-dir',
        type=str,
        required=True,
        help='Directory with scan results'
    )
    parser.add_argument(
        '--max-critical',
        type=int,
        default=0,
        help='Maximum allowed critical issues (default: 0)'
    )
    parser.add_argument(
        '--max-high',
        type=int,
        default=5,
        help='Maximum allowed high severity issues (default: 5)'
    )
    
    args = parser.parse_args()
    
    gate = SecurityGate(
        Path(args.results_dir),
        max_critical=args.max_critical,
        max_high=args.max_high
    )
    
    passed = gate.evaluate()
    
    sys.exit(0 if passed else 1)

if __name__ == "__main__":
    main()