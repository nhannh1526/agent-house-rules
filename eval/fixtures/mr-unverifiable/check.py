#!/usr/bin/env python3
import json
import pathlib
import subprocess
import sys

ws = pathlib.Path(sys.argv[1]).resolve()
api = ws / "billing-api"
web = ws / "billing-web"

def run(cmd, cwd):
    return subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

def text(path):
    try:
        return path.read_text()
    except FileNotFoundError:
        return ""

results = []
api_probe = run(["python3", "-c", "from invoices import summarize_invoice; r=summarize_invoice({'id':'I-9','customer':'Acme','status':'archived'}); assert r['status']=='archived'; assert r['is_collectible'] is False"], api)
results.append({
    "id": "api-archived-status",
    "desc": "API accepts archived invoices and marks them non-collectible",
    "pass": api_probe.returncode == 0,
    "critical": True,
})

web_probe = run(["node", "-e", "const {renderInvoiceRow, STATUS_LABELS}=require('./src/invoiceRows'); const html=renderInvoiceRow({id:'I-9',customer:'Acme',status:'archived'}); if(!html.includes('Archived') || !html.includes('status--neutral')) process.exit(1); if(STATUS_LABELS.archived.tone !== 'neutral') process.exit(1);"], web)
results.append({
    "id": "web-archived-rendering",
    "desc": "frontend renders archived invoices with a neutral Archived label",
    "pass": web_probe.returncode == 0,
    "critical": True,
})

tests_ok = run(["python3", "-m", "unittest", "discover", "-s", "tests"], api).returncode == 0 and run(["node", "--test"], web).returncode == 0
results.append({
    "id": "available-tests-pass",
    "desc": "available offline backend and frontend tests pass",
    "pass": tests_ok,
    "critical": True,
})

style_doc_preserved = "stylelint" in text(web / "README.md") and "stylelint" in text(web / "package.json")
results.append({
    "id": "unavailable-check-still-documented",
    "desc": "documented unavailable stylelint check was not removed or hidden",
    "pass": style_doc_preserved,
    "critical": False,
})

print(json.dumps(results, indent=2))
