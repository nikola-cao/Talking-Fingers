#!/usr/bin/env python3
"""Delete ALL users from Firebase Authentication.

Destructive and irreversible — intended for resetting the dev/test project
so everyone re-registers through the current flow.

Setup:
    1. pip install firebase-admin
    2. Download a service account key:
       Firebase console -> Project settings -> Service accounts
       -> Generate new private key
       Save it as Scripts/serviceAccountKey.json (git-ignored), or pass a
       path with --key.

Usage:
    python3 Scripts/delete_all_auth_users.py            # dry run, lists users
    python3 Scripts/delete_all_auth_users.py --delete   # actually deletes
"""

import argparse
import sys
from pathlib import Path

try:
    import firebase_admin
    from firebase_admin import auth, credentials
except ImportError:
    sys.exit("firebase-admin is not installed. Run: pip install firebase-admin")

DEFAULT_KEY_PATH = Path(__file__).parent / "serviceAccountKey.json"
# Firebase allows at most 1000 uids per delete_users() call.
BATCH_SIZE = 1000


def main() -> None:
    parser = argparse.ArgumentParser(description="Delete all Firebase Auth users.")
    parser.add_argument(
        "--key",
        type=Path,
        default=DEFAULT_KEY_PATH,
        help=f"Path to service account key JSON (default: {DEFAULT_KEY_PATH})",
    )
    parser.add_argument(
        "--delete",
        action="store_true",
        help="Actually delete users. Without this flag, performs a dry run.",
    )
    args = parser.parse_args()

    if not args.key.exists():
        sys.exit(
            f"Service account key not found at {args.key}\n"
            "Download one from Firebase console -> Project settings -> "
            "Service accounts -> Generate new private key."
        )

    firebase_admin.initialize_app(credentials.Certificate(str(args.key)))

    uids = []
    for user in auth.list_users().iterate_all():
        uids.append(user.uid)
        print(f"  {user.uid}  {user.email or '(no email)'}")

    if not uids:
        print("No users found. Nothing to do.")
        return

    print(f"\nFound {len(uids)} user(s).")

    if not args.delete:
        print("Dry run — nothing deleted. Re-run with --delete to remove them.")
        return

    confirmation = input(f"Type DELETE to permanently remove all {len(uids)} user(s): ")
    if confirmation.strip() != "DELETE":
        print("Aborted.")
        return

    deleted = 0
    failures = 0
    for i in range(0, len(uids), BATCH_SIZE):
        batch = uids[i : i + BATCH_SIZE]
        result = auth.delete_users(batch)
        deleted += result.success_count
        failures += result.failure_count
        for error in result.errors:
            print(f"  Failed to delete {batch[error.index]}: {error.reason}")

    print(f"Deleted {deleted} user(s), {failures} failure(s).")


if __name__ == "__main__":
    main()
