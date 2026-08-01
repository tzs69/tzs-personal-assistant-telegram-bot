import os
from dotenv import load_dotenv
from pathlib import Path
import requests
import getopt
import sys

load_dotenv(dotenv_path=Path(__file__).resolve().parents[1] / ".env")

TELE_BOT_API_KEY = os.environ.get("TELE_BOT_API_KEY")


def main():

    run_destroy = False

    opts, args = getopt.getopt(sys.argv[1:3], shortopts="", longopts=["delete"])

    # Parse only if both option and argument are present
    try:
        if len(opts) != 0:
            opt, arg = opts[0], args[0]
            if opt[0] == "--delete":
                if (arg == "true" or arg == "1"):
                    run_destroy = True
    except Exception:
        print("invalid argument/option detected, running normal setWebhook script")

    webhook_command = "setWebhook" if not run_destroy else "deleteWebhook"
    configure_webhook_url = f"https://api.telegram.org/bot{TELE_BOT_API_KEY}/{webhook_command}"

    data = None
    if not run_destroy:
        webhook_lambda_url = os.environ.get("WEBHOOK_LAMBDA_URL")
        if not webhook_lambda_url:
            print("WEBHOOK_LAMBDA_URL not set")
            sys.exit(1)

        data = {"url": webhook_lambda_url}

    response = requests.post(configure_webhook_url, data=data)

    response_json = response.json()
    ok = response_json.get("ok", "")
    description = response_json.get("description", "")
    if (ok and (description == "Webhook was set" or description == "Webhook is already set")):
        print("Webhook set successfully")
    if (ok and (description == "Webhook was deleted" or description == "Webhook is already deleted")):
        print("Webhook deleted successfully")
    if (not ok and not run_destroy):
        print("Webhook set failed")
    if (not ok and run_destroy):
        print("Webhook delete failed")
    

if __name__ == "__main__":
    main()