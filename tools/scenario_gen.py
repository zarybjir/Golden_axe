"""Generování přes Scenario API (přihlášení dodává síťová proxy prostředí).

Použití:
  python3 tools/scenario_gen.py MODEL "prompt" vystup.png [klic=hodnota ...] [--dry]
Příklad:
  python3 tools/scenario_gen.py model_bfl-flux-2-klein-4b "swamp" swamp.png aspectRatio=21:9
--dry jen vypíše cenu v kreditech a nic negeneruje.
"""
import json
import subprocess
import sys
import time

API = "https://api.cloud.scenario.com/v1"


def call(method, path, body=None):
    cmd = ["curl", "-sS", "-X", method, API + path, "-H", "Content-Type: application/json"]
    if body is not None:
        cmd += ["-d", json.dumps(body)]
    return json.loads(subprocess.check_output(cmd))


def main():
    model, prompt, out = sys.argv[1], sys.argv[2], sys.argv[3]
    dry = "--dry" in sys.argv
    params = {"prompt": prompt}
    for a in sys.argv[4:]:
        if "=" in a:
            k, v = a.split("=", 1)
            params[k] = int(v) if v.isdigit() else v
    est = call("POST", f"/generate/custom/{model}?dryRun=true", params)
    print("cena:", est.get("creativeUnitsCost", est))
    if dry:
        return
    job = call("POST", f"/generate/custom/{model}", params)
    jid = job.get("job", job).get("jobId")
    print("job:", jid)
    while True:
        time.sleep(3)
        j = call("GET", f"/jobs/{jid}")["job"]
        st = j.get("status")
        if st in ("success", "succeeded"):
            break
        if st in ("failure", "failed", "canceled"):
            print("CHYBA:", json.dumps(j)[:800])
            sys.exit(1)
    ids = j.get("metadata", {}).get("assetIds") or [a.get("assetId") or a.get("id") for a in j.get("assets", [])]
    for n, aid in enumerate(ids):
        a = call("GET", f"/assets/{aid}")["asset"]
        name = out if len(ids) == 1 else out.replace(".", f"_{n}.", 1)
        subprocess.check_call(["curl", "-sS", "-L", "-o", name, a["url"]])
        print("uloženo:", name)


if __name__ == "__main__":
    main()
