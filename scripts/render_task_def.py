#!/usr/bin/env python3
"""Render a new ECS task definition JSON (for `register-task-definition --cli-input-json`) from an
existing task definition description, swapping in a new container image.

Usage: render_task_def.py <describe-task-definition-output.json> <new-image-uri>
"""
import json
import sys

ALLOWED_KEYS = {
    "family",
    "containerDefinitions",
    "cpu",
    "memory",
    "networkMode",
    "requiresCompatibilities",
    "executionRoleArn",
    "taskRoleArn",
    "volumes",
}


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(f"Usage: {sys.argv[0]} <task-def.json> <new-image-uri>")

    with open(sys.argv[1], encoding="utf-8") as f:
        task_def = json.load(f)

    new_image = sys.argv[2]
    task_def["containerDefinitions"][0]["image"] = new_image

    filtered = {key: value for key, value in task_def.items() if key in ALLOWED_KEYS}
    print(json.dumps(filtered))


if __name__ == "__main__":
    main()
