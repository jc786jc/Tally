#!/usr/bin/env python3
"""
Test script to verify VM setup and BigQuery connectivity
Run this after completing the VM setup to ensure everything works
"""

import sys
import os
from datetime import datetime

def test_bigquery_connectivity():
    """Test BigQuery connection and data access"""
    print("🔍 Testing BigQuery connectivity...")

    try:
        from google.cloud import bigquery

        # Initialize client
        client = bigquery.Client(project='datarecsv2')

        # Test DQM data
        query = "SELECT COUNT(*) as count FROM `datarecsv2.dqm_data.camp_transactions`"
        result = client.query(query).result()
        dqm_count = list(result)[0][0]
        print(f"✅ DQM test data: {dqm_count} rows")

        # Test TTCM data
        query = "SELECT COUNT(*) as count FROM `datarecsv2.ttcm_data.sscrtyp_prev`"
        result = client.query(query).result()
        ttcm_count = list(result)[0][0]
        print(f"✅ TTCM ML15 prev data: {ttcm_count} rows")

        return True

    except Exception as e:
        print(f"❌ BigQuery test failed: {e}")
        return False

def test_dqm_ttcm_execution_scripts():
    """Verify runtime execution scripts for DQM and TTCM are present."""
    print("🔍 Checking DQM/TTCM execution scripts...")

    missing = []
    for script in ['run_dqm.py', 'run_ttcm.py']:
        if not os.path.exists(script):
            missing.append(script)

    if missing:
        print(f"❌ Missing execution scripts: {', '.join(missing)}")
        return False

    print("✅ Execution scripts are present")
    return True

def test_web_services():
    """Test that web services are running"""
    print("🔍 Testing web services...")

    import requests

    try:
        # Test Tally web server
        response = requests.get('http://localhost', timeout=5)
        if response.status_code == 200:
            print("✅ Tally web server responding")
        else:
            print(f"⚠️ Tally web server returned status {response.status_code}")

        return True

    except requests.exceptions.RequestException as e:
        print(f"❌ Web service test failed: {e}")
        return False

def main():
    """Run all tests"""
    print(f"🚀 Starting VM setup verification at {datetime.now()}")
    print("=" * 50)

    tests = [
        ("BigQuery Connectivity", test_bigquery_connectivity),
        ("DQM/TTCM Script Availability", test_dqm_ttcm_execution_scripts),
        ("Web Services", test_web_services),
    ]

    results = []
    for test_name, test_func in tests:
        print(f"\n📋 Running {test_name} test...")
        result = test_func()
        results.append((test_name, result))

    print("\n" + "=" * 50)
    print("📊 Test Results Summary:")

    all_passed = True
    for test_name, passed in results:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"  {test_name}: {status}")
        if not passed:
            all_passed = False

    print("\n" + "=" * 50)
    if all_passed:
        print("🎉 All tests passed! Your VM setup is ready.")
        print("\nNext steps:")
        print("1. Access Tally app at http://your-vm-ip")
        print("2. Run DQM and TTCM execution scripts manually")
        print("3. Monitor logs and BigQuery results")
    else:
        print("⚠️ Some tests failed. Please review the errors above and fix issues before going to production.")
        print("\nCommon fixes:")
        print("- Check GOOGLE_APPLICATION_CREDENTIALS environment variable")
        print("- Verify BigQuery permissions")
        print("- Ensure Tally is running: sudo systemctl status tally-server")

    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())