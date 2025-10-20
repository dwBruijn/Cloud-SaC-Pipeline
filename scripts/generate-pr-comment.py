#!/usr/bin/env python3
"""
Generate a formatted PR comment from security scan results
"""

import argparse
import json
from pathlib import Path
from datetime import datetime
from collections import defaultdict

def load_checkov_results(results_dir: Path) -> dict:
    """Load Checkov results from JSON file"""
    checkov_file = results_dir / "results_json.json"
    if not checkov_file.exists():
        return {}
    
    with open(checkov_file, 'r') as f:
        return json.load(f)

def categorize_by_severity(findings: list) -> dict:
    """Categorize findings by severity"""
    severity_map = {
        'CRITICAL': [],
        'HIGH': [],
        'MEDIUM': [],
        'LOW': []
    }
    
    for finding in findings:
        check_id = finding.get('check_id', '')
        
        # Map check IDs to severity (enhanced logic)
        if any(cid in check_id for cid in ['CKV_GCP_62', 'CKV_GCP_6', 'CKV_GCP_14']):
            severity = 'CRITICAL'
        elif 'CKV_GCP' in check_id or 'CKV_AWS' in check_id:
            severity = 'HIGH'
        elif 'CKV2' in check_id:
            severity = 'MEDIUM'
        else:
            severity = 'LOW'
        
        finding['severity'] = severity
        severity_map[severity].append(finding)
    
    return severity_map

def truncate_text(text: str, max_length: int = 80) -> str:
    """Truncate text to max length"""
    if len(text) <= max_length:
        return text
    return text[:max_length-3] + "..."

def generate_pr_comment(results_dir: Path) -> str:
    """Generate formatted markdown for PR comment"""
    
    checkov_data = load_checkov_results(results_dir)
    
    if not checkov_data:
        return "⚠️ Could not load security scan results"
    
    # Extract data
    summary = checkov_data.get('summary', {})
    failed_checks = checkov_data.get('results', {}).get('failed_checks', [])
    passed_checks = checkov_data.get('results', {}).get('passed_checks', [])
    
    # Categorize findings
    severity_findings = categorize_by_severity(failed_checks)
    
    # Count by severity
    critical_count = len(severity_findings['CRITICAL'])
    high_count = len(severity_findings['HIGH'])
    medium_count = len(severity_findings['MEDIUM'])
    low_count = len(severity_findings['LOW'])
    
    total_failed = summary.get('failed', 0)
    total_passed = summary.get('passed', 0)
    
    # Determine overall status
    if critical_count > 0:
        status_emoji = "🔴"
        status_text = "FAILED - Critical issues found"
    elif high_count > 5:
        status_emoji = "🟠"
        status_text = "WARNING - Multiple high severity issues"
    elif high_count > 0:
        status_emoji = "🟡"
        status_text = "ATTENTION - High severity issues found"
    else:
        status_emoji = "🟢"
        status_text = "PASSED - No critical/high issues"
    
    # Build comment
    lines = []
    
    # Header
    lines.append("## 🔒 Security Scan Results")
    lines.append("")
    lines.append(f"**Status:** {status_emoji} {status_text}")
    lines.append(f"**Scanned at:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}")
    lines.append("")
    
    # Summary statistics
    lines.append("### 📊 Summary")
    lines.append("")
    lines.append("| Metric | Count |")
    lines.append("|--------|-------|")
    lines.append(f"| ✅ Passed Checks | {total_passed} |")
    lines.append(f"| ❌ Failed Checks | {total_failed} |")
    lines.append("")
    
    # Severity breakdown
    lines.append("### 🎯 Severity Breakdown")
    lines.append("")
    lines.append("| Severity | Count | Status |")
    lines.append("|----------|-------|--------|")
    lines.append(f"| 🔴 Critical | {critical_count} | {'⛔ Must Fix' if critical_count > 0 else '✅'} |")
    lines.append(f"| 🟠 High | {high_count} | {'⚠️ Should Fix' if high_count > 0 else '✅'} |")
    lines.append(f"| 🟡 Medium | {medium_count} | {'📝 Consider' if medium_count > 0 else '✅'} |")
    lines.append(f"| ⚪ Low | {low_count} | {'ℹ️ Optional' if low_count > 0 else '✅'} |")
    lines.append("")
    
    # Critical findings (show all)
    if critical_count > 0:
        lines.append("### 🔴 Critical Issues (Must Fix)")
        lines.append("")
        lines.append("<details open>")
        lines.append("<summary>Click to expand critical findings</summary>")
        lines.append("")
        lines.append("| Check | Resource | File | Lines |")
        lines.append("|-------|----------|------|-------|")
        
        for finding in severity_findings['CRITICAL'][:10]:  # Limit to 10
            check_name = truncate_text(finding.get('check_name', 'Unknown'), 50)
            resource = truncate_text(finding.get('resource', 'Unknown'), 40)
            file_path = finding.get('file_path', '').lstrip('/')
            lines_range = finding.get('file_line_range', [0, 0])
            line_str = f"{lines_range[0]}-{lines_range[1]}" if len(lines_range) == 2 else "N/A"
            
            lines.append(f"| {check_name} | `{resource}` | `{file_path}` | {line_str} |")
        
        if critical_count > 10:
            lines.append("")
            lines.append(f"*...and {critical_count - 10} more critical issues*")
        
        lines.append("")
        lines.append("</details>")
        lines.append("")
    
    # High findings (show top 10)
    if high_count > 0:
        lines.append("### 🟠 High Severity Issues")
        lines.append("")
        lines.append("<details>")
        lines.append(f"<summary>Click to expand {high_count} high severity findings</summary>")
        lines.append("")
        lines.append("| Check | Resource | File |")
        lines.append("|-------|----------|------|")
        
        for finding in severity_findings['HIGH'][:10]:
            check_name = truncate_text(finding.get('check_name', 'Unknown'), 50)
            resource = truncate_text(finding.get('resource', 'Unknown'), 40)
            file_path = finding.get('file_path', '').lstrip('/')
            
            lines.append(f"| {check_name} | `{resource}` | `{file_path}` |")
        
        if high_count > 10:
            lines.append("")
            lines.append(f"*...and {high_count - 10} more high severity issues*")
        
        lines.append("")
        lines.append("</details>")
        lines.append("")
    
    # Medium findings (summarized)
    if medium_count > 0:
        lines.append("### 🟡 Medium Severity Issues")
        lines.append("")
        lines.append("<details>")
        lines.append(f"<summary>{medium_count} medium severity issues found (click to expand top 5)</summary>")
        lines.append("")
        
        for finding in severity_findings['MEDIUM'][:5]:
            check_name = finding.get('check_name', 'Unknown')
            resource = finding.get('resource', 'Unknown')
            lines.append(f"- {check_name} in `{resource}`")
        
        if medium_count > 5:
            lines.append(f"- *...and {medium_count - 5} more*")
        
        lines.append("")
        lines.append("</details>")
        lines.append("")
    
    # Low findings (just count)
    if low_count > 0:
        lines.append(f"### ⚪ Low Severity: {low_count} issues")
        lines.append("")
    
    # Top affected files
    file_counts = defaultdict(int)
    for finding in failed_checks:
        file_path = finding.get('file_path', '').lstrip('/')
        if file_path:
            file_counts[file_path] += 1
    
    if file_counts:
        lines.append("### 📁 Most Affected Files")
        lines.append("")
        lines.append("| File | Issues |")
        lines.append("|------|--------|")
        
        sorted_files = sorted(file_counts.items(), key=lambda x: x[1], reverse=True)[:5]
        for file_path, count in sorted_files:
            lines.append(f"| `{file_path}` | {count} |")
        
        lines.append("")
    
    # Action items
    lines.append("### 🎯 Next Steps")
    lines.append("")
    
    if critical_count > 0:
        lines.append("⛔ **Action Required:**")
        lines.append(f"- Fix {critical_count} critical security issue(s) before merging")
        lines.append("")
    
    if high_count > 0:
        lines.append("⚠️ **Strongly Recommended:**")
        lines.append(f"- Address {high_count} high severity issue(s)")
        lines.append("")
    
    if medium_count > 0 or low_count > 0:
        lines.append("📝 **Consider:**")
        lines.append(f"- Review and address medium/low severity findings when possible")
        lines.append("")
    
    # Footer
    lines.append("---")
    lines.append("")
    lines.append("💡 **View Details:**")
    lines.append("- Download the `security-scan-results` artifact from this workflow run")
    lines.append("- Check the **Security** tab for SARIF analysis")
    lines.append("- Review `scan-results/checkov-results.json` for complete findings")
    lines.append("")
    lines.append("🔧 **Tools Used:** Checkov, tfsec, Terraform Validate")
    lines.append("")
    lines.append("*This comment will be automatically updated on new commits*")
    
    return "\n".join(lines)

def main():
    parser = argparse.ArgumentParser(description="Generate PR comment from security scan results")
    parser.add_argument('--results-dir', type=str, required=True, help='Directory with scan results')
    parser.add_argument('--output', type=str, required=True, help='Output markdown file')
    
    args = parser.parse_args()
    
    results_dir = Path(args.results_dir)
    if not results_dir.exists():
        print(f"Error: Results directory {results_dir} does not exist")
        return 1
    
    # Generate comment
    comment = generate_pr_comment(results_dir)
    
    # Write to file
    with open(args.output, 'w') as f:
        f.write(comment)
    
    print(f"✓ PR comment generated: {args.output}")
    return 0

if __name__ == "__main__":
    exit(main())