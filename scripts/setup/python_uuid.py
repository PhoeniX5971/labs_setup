import json
import uuid
from pathlib import Path

JSON_FILE = Path("uuid_mappings.json")


def load_mappings():
    if JSON_FILE.exists():
        return json.loads(JSON_FILE.read_text())
    return {}


def save_mappings(mappings):
    JSON_FILE.write_text(json.dumps(mappings, indent=4))


def list_mappings(mappings):
    if not mappings:
        print("No mappings available.")
    else:
        for uid, name in mappings.items():
            print(f"{uid} -> {name}")


def add_mapping(mappings, name, uid=None):
    uid = uid or str(uuid.uuid4())
    mappings[uid] = name
    save_mappings(mappings)
    print(f"Added: {uid} -> {name}")


def edit_by_uuid(mappings, uid, new_name):
    if uid in mappings:
        mappings[uid] = new_name
        save_mappings(mappings)
        print(f"Updated {uid} -> {new_name}")
    else:
        print("UUID not found")


def edit_by_name(mappings, old_name, new_name):
    for uid, name in mappings.items():
        if name == old_name:
            mappings[uid] = new_name
            save_mappings(mappings)
            print(f"Updated {uid} -> {new_name}")
            return
    print("Name not found")


def delete_by_uuid(mappings, uid):
    if uid in mappings:
        removed = mappings.pop(uid)
        save_mappings(mappings)
        print(f"Deleted {uid} -> {removed}")
    else:
        print("UUID not found")


def delete_by_name(mappings, name):
    for uid, n in list(mappings.items()):
        if n == name:
            mappings.pop(uid)
            save_mappings(mappings)
            print(f"Deleted {uid} -> {name}")
            return
    print("Name not found")


def reset_uuid(mappings, name):
    """Assign new UUID to an existing script name."""
    for uid, n in list(mappings.items()):
        if n == name:
            new_uid = str(uuid.uuid4())
            mappings.pop(uid)
            mappings[new_uid] = n
            save_mappings(mappings)
            print(f"Reset UUID: {new_uid} -> {n}")
            return
    print("Name not found")


def main():
    mappings = load_mappings()

    while True:
        print("\n--- UUID Mapper ---")
        print("1. List mappings")
        print("2. Add mapping")
        print("3. Edit by UUID")
        print("4. Edit by Name")
        print("5. Delete by UUID")
        print("6. Delete by Name")
        print("7. Reset UUID for Name")
        print("8. Exit")

        choice = input("Select an option: ").strip()

        if choice == "1":
            list_mappings(mappings)

        elif choice == "2":
            name = input("Enter script name: ").strip()
            uid_input = input("Enter UUID (leave blank for auto): ").strip()
            uid = uid_input if uid_input else None
            add_mapping(mappings, name, uid)

        elif choice == "3":
            uid = input("Enter UUID to edit: ").strip()
            new_name = input("Enter new name: ").strip()
            edit_by_uuid(mappings, uid, new_name)

        elif choice == "4":
            old_name = input("Enter current name: ").strip()
            new_name = input("Enter new name: ").strip()
            edit_by_name(mappings, old_name, new_name)

        elif choice == "5":
            uid = input("Enter UUID to delete: ").strip()
            delete_by_uuid(mappings, uid)

        elif choice == "6":
            name = input("Enter name to delete: ").strip()
            delete_by_name(mappings, name)

        elif choice == "7":
            name = input("Enter name to reset UUID: ").strip()
            reset_uuid(mappings, name)

        elif choice == "8":
            print("Exiting...")
            break

        else:
            print("Invalid choice, try again.")


if __name__ == "__main__":
    main()
