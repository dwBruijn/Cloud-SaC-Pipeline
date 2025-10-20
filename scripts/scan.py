#!/usr/bin/env python3
"""
Security-as-Code Scanner
Orchestrates multiple security scanning tools for Infrastructure-as-Code
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Tuple
from datetime import datetime
import os

class Colors:
    """ANSI color codes for terminal output"""
    RED = '\033[91m'
    YELLOW = '\033[93m'
    GREEN = '\033[92m'
    BLUE = '\033[94m'
    BOLD = '\033[1m'
    END = '\033[0m'

class SecurityScanner:
    def __init__(self, scan_path: str, output_dir: str = "scan-results"):
        self.scan_path = Path(scan_path)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        self.results = {
            "checkov": None,
            "tfsec": None,
            "terraform_validate": None
        }
        
    def print_header(self, text: str):
        """Print formatted section header"""
        print(f"\n{Colors.BLUE}{Colors.BOLD}{'='*60}{Colors.END}")
        print(f"{Colors.BLUE}{Colors.BOLD}{text}{Colors.END}")
        print(f"{Colors.BLUE}{Colors.BOLD}{'='*60}{Colors.END}\n")
    
    def print_status(self, tool: str, status: str, details: str = ""):
        """Print tool execution status"""
        status_color = Colors.GREEN if status == "PASS" else Colors.RED if status == "FAIL" else Colors.YELLOW
        print(f"[{status_color}{status}{Colors.END}] {tool}: {details}")
    
    def run_terraform_validate(self) -> Tuple[bool, Dict]:
        """Run terraform validate"""
        self.print_header("Running Terraform Validate")
        
        result = {
            "passed": False,
            "errors": [],
            "timestamp": datetime.now().isoformat()
        }
        
        try:
            # Initialize terraform (without backend)
            init_cmd = ["terraform", "init", "-backend=false"]
            subprocess.run(
                init_cmd,
                cwd=self.scan_path,
                capture_output=True,
                check=True,
                text=True
            )
            
            # Run validation
            validate_cmd = ["terraform", "validate", "-json"]
            process = subprocess.run(
                validate_cmd,
                cwd=self.scan_path,
                capture_output=True,
                text=True
            )
            
            output = json.loads(process.stdout)
            
            if output.get("valid", False):
                result["passed"] = True
                self.print_status("Terraform Validate", "PASS", "Configuration is valid")
            else:
                result["passed"] = False
                result["errors"] = output.get("diagnostics", [])
                self.print_status("Terraform Validate", "FAIL", f"{len(result['errors'])} errors found")
                
                # Print errors
                for error in result["errors"]:
                    print(f"  {Colors.RED}✗{Colors.END} {error.get('summary', 'Unknown error')}")
                    if error.get('detail'):
                        print(f"    {error['detail']}")
            
        except subprocess.CalledProcessError as e:
            result["passed"] = False
            result["errors"] = [{"summary": "Terraform command failed", "detail": e.stderr}]
            self.print_status("Terraform Validate", "FAIL", "Command execution failed")
        except Exception as e:
            result["passed"] = False
            result["errors"] = [{"summary": str(e)}]
            self.print_status("Terraform Validate", "FAIL", str(e))
        
        self.results["terraform_validate"] = result
        return result["passed"], result
    
    def run_checkov(self) -> Tuple[bool, Dict]:
        """Run Checkov security scanner"""
        self.print_header("Running Checkov")
        
        output_file = self.output_dir / "results_json.json"
        
        result = {
            "passed": False,
            "summary": {},
            "findings": [],
            "timestamp": datetime.now().isoformat()
        }
        
        try:
            cmd = [
                "checkov",
                "-d", str(self.scan_path),
                "--framework", "terraform",
                "--output", "json",
                "--output", "sarif",
                "--output-file-path", str(self.output_dir),
                "--soft-fail"  # Don't exit with error code
            ]
            
            process = subprocess.run(
                cmd,
                capture_output=True,
                text=True
            )
            
            # Read the JSON output
            if output_file.exists():
                with open(output_file, 'r') as f:
                    checkov_output = json.load(f)
                
                # Parse results
                summary = checkov_output.get("summary", {})
                result["summary"] = {
                    "passed": summary.get("passed", 0),
                    "failed": summary.get("failed", 0),
                    "skipped": summary.get("skipped", 0),
                    "parsing_errors": summary.get("parsing_errors", 0)
                }
                
                # Extract failed checks
                for check_type in checkov_output.get("results", {}).get("failed_checks", []):
                    result["findings"].append({
                        "check_id": check_type.get("check_id"),
                        "check_name": check_type.get("check_name"),
                        "file": check_type.get("file_path"),
                        "resource": check_type.get("resource"),
                        "severity": self._map_checkov_severity(check_type.get("check_id")),
                        "guideline": check_type.get("guideline", "")
                    })
                
                # Determine pass/fail
                critical_count = sum(1 for f in result["findings"] if f["severity"] == "CRITICAL")
                high_count = sum(1 for f in result["findings"] if f["severity"] == "HIGH")
                
                result["passed"] = critical_count == 0 and high_count <= 5
                
                # Print summary
                self.print_status(
                    "Checkov",
                    "PASS" if result["passed"] else "FAIL",
                    f"Passed: {result['summary']['passed']}, Failed: {result['summary']['failed']}"
                )
                
                print(f"\n  Severity Breakdown:")
                severity_counts = {}
                for finding in result["findings"]:
                    sev = finding["severity"]
                    severity_counts[sev] = severity_counts.get(sev, 0) + 1
                
                for severity in ["CRITICAL", "HIGH", "MEDIUM", "LOW"]:
                    count = severity_counts.get(severity, 0)
                    if count > 0:
                        color = Colors.RED if severity == "CRITICAL" else Colors.YELLOW if severity == "HIGH" else Colors.END
                        print(f"    {color}{severity}: {count}{Colors.END}")
            
        except Exception as e:
            self.print_status("Checkov", "FAIL", str(e))
            result["error"] = str(e)
        
        self.results["checkov"] = result
        return result["passed"], result
    
    def run_tfsec(self) -> Tuple[bool, Dict]:
        """Run tfsec security scanner"""
        self.print_header("Running tfsec")
        
        result = {
            "passed": False,
            "findings": [],
            "timestamp": datetime.now().isoformat()
        }
        
        # Check if tfsec is installed
        try:
            subprocess.run(["tfsec", "--version"], capture_output=True, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError):
            self.print_status("tfsec", "SKIP", "tfsec not installed (optional)")
            result["skipped"] = True
            self.results["tfsec"] = result
            return True, result
        
        try:
            cmd = [
                "tfsec",
                str(self.scan_path),
                "--format", "json",
                "--soft-fail"
            ]
            
            process = subprocess.run(
                cmd,
                capture_output=True,
                text=True
            )
            
            if process.stdout:
                tfsec_output = json.loads(process.stdout)
                
                for finding in tfsec_output.get("results", []):
                    result["findings"].append({
                        "rule_id": finding.get("rule_id"),
                        "description": finding.get("description"),
                        "severity": finding.get("severity", "UNKNOWN").upper(),
                        "file": finding.get("location", {}).get("filename"),
                        "line": finding.get("location", {}).get("start_line")
                    })
                
                critical_count = sum(1 for f in result["findings"] if f["severity"] == "CRITICAL")
                high_count = sum(1 for f in result["findings"] if f["severity"] == "HIGH")
                
                result["passed"] = critical_count == 0 and high_count <= 5
                
                self.print_status(
                    "tfsec",
                    "PASS" if result["passed"] else "FAIL",
                    f"Found {len(result['findings'])} issues"
                )
                
        except Exception as e:
            self.print_status("tfsec", "FAIL", str(e))
            result["error"] = str(e)
        
        self.results["tfsec"] = result
        return result.get("passed", False), result
    
    def _map_checkov_severity(self, check_id: str) -> str:
        """Map Checkov check IDs to severity levels"""
        # Simple heuristic - can be improved with actual severity mapping
        critical_patterns = ["CKV_GCP_6", "CKV_GCP_62", "CKV_GCP_14"]  # Public access, encryption
        high_patterns = ["CKV_GCP_", "CKV_AWS_"]
        
        if any(pattern in check_id for pattern in critical_patterns):
            return "CRITICAL"
        elif any(pattern in check_id for pattern in high_patterns):
            return "HIGH"
        else:
            return "MEDIUM"
    
    def generate_summary_report(self) -> str:
        """Generate a summary report of all scans"""
        self.print_header("Scan Summary")
        
        report_lines = []
        report_lines.append(f"Security Scan Report - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report_lines.append(f"Scanned Path: {self.scan_path}")
        report_lines.append("=" * 60)
        report_lines.append("")
        
        # Overall status
        all_passed = all(
            r.get("passed", False) if r and not r.get("skipped") else True 
            for r in self.results.values()
        )
        
        status = f"{Colors.GREEN}✓ PASSED{Colors.END}" if all_passed else f"{Colors.RED}✗ FAILED{Colors.END}"
        report_lines.append(f"Overall Status: {status}")
        report_lines.append("")
        
        # Individual tool results
        report_lines.append("Tool Results:")
        report_lines.append("-" * 60)
        
        for tool, result in self.results.items():
            if result is None:
                continue
            
            if result.get("skipped"):
                report_lines.append(f"  {tool}: SKIPPED")
                continue
            
            passed = result.get("passed", False)
            status_icon = "✓" if passed else "✗"
            status_color = Colors.GREEN if passed else Colors.RED
            
            if tool == "checkov":
                summary = result.get("summary", {})
                report_lines.append(
                    f"  {status_color}{status_icon}{Colors.END} {tool}: "
                    f"{summary.get('failed', 0)} failed checks"
                )
            elif tool == "tfsec":
                report_lines.append(
                    f"  {status_color}{status_icon}{Colors.END} {tool}: "
                    f"{len(result.get('findings', []))} issues found"
                )
            elif tool == "terraform_validate":
                report_lines.append(
                    f"  {status_color}{status_icon}{Colors.END} {tool}: "
                    f"{'Valid' if passed else 'Invalid'}"
                )
        
        report_lines.append("")
        report_lines.append(f"Detailed results saved to: {self.output_dir}")
        
        report_text = "\n".join(report_lines)
        print(report_text)
        
        # Save to file
        summary_file = self.output_dir / "summary.txt"
        with open(summary_file, 'w') as f:
            # Remove color codes for file
            clean_text = report_text
            for color in [Colors.RED, Colors.GREEN, Colors.YELLOW, Colors.BLUE, Colors.BOLD, Colors.END]:
                clean_text = clean_text.replace(color, '')
            f.write(clean_text)
        
        return report_text
    
    def run_all_scans(self) -> bool:
        """Run all security scans"""
        print(f"{Colors.BOLD}Security-as-Code Scanner{Colors.END}")
        print(f"Scanning: {self.scan_path}\n")
        
        # Run scans
        tf_passed, _ = self.run_terraform_validate()
        checkov_passed, _ = self.run_checkov()
        tfsec_passed, _ = self.run_tfsec()
        
        # Generate summary
        self.generate_summary_report()
        
        # Return overall pass/fail
        return tf_passed and checkov_passed and tfsec_passed

def main():
    parser = argparse.ArgumentParser(
        description="Security-as-Code Scanner for Terraform",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scan.py --path terraform/vulnerable-examples
  python scan.py --path terraform/vulnerable-examples --output-dir results
        """
    )
    
    parser.add_argument(
        '--path',
        type=str,
        required=True,
        help='Path to Terraform code to scan'
    )
    
    parser.add_argument(
        '--output-dir',
        type=str,
        default='scan-results',
        help='Directory to save scan results (default: scan-results)'
    )
    
    args = parser.parse_args()
    
    # Check if path exists
    if not Path(args.path).exists():
        print(f"{Colors.RED}Error: Path '{args.path}' does not exist{Colors.END}")
        sys.exit(1)
    
    # Run scanner
    scanner = SecurityScanner(args.path, args.output_dir)
    success = scanner.run_all_scans()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()