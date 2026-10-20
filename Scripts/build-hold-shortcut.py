#!/usr/bin/env python3
"""Build the guarded, two-minute Hold Calls shortcut. Sign with `shortcuts sign`."""
import pathlib
import plistlib
import uuid


def uid():
    return str(uuid.uuid4()).upper()


def variable(identifier, name):
    return {"OutputUUID": identifier, "Type": "ActionOutput", "OutputName": name}


def attachment(value):
    return {"Value": value, "WFSerializationType": "WFTextTokenAttachment"}


def token(value, prefix=""):
    return {"Value": {"string": prefix + "\ufffc", "attachmentsByRange": {
        "{%d, 1}" % len(prefix): value}}, "WFSerializationType": "WFTextTokenString"}


def action(name, **parameters):
    return {"WFWorkflowActionIdentifier": "is.workflow.actions." + name,
            "WFWorkflowActionParameters": parameters}


input_id, focus_id, text_id, date_id, held_id, result_id, blocked_id, group = [uid() for _ in range(8)]
actions = [
    action("detect.text", UUID=input_id, WFInput=attachment({"Type": "ExtensionInput"})),
    action("dnd.getfocus", UUID=focus_id),
    action("gettext", UUID=text_id, WFTextActionText=token(variable(focus_id, "Current Focus"), "focus:")),
    action("conditional", GroupingIdentifier=group, WFControlFlowMode=0, WFCondition=4,
           WFInput={"Type": "Variable", "Variable": attachment(variable(text_id, "Text"))},
           WFConditionalActionString=token(variable(input_id, "Text"))),
    action("adjustdate", UUID=date_id, WFAdjustOperation="Add", WFDate=token({"Type": "CurrentDate"}),
           WFDuration={"Value": {"Unit": "min", "Magnitude": 2}, "WFSerializationType": "WFQuantityFieldValue"}),
    action("dnd.set", Enabled=1, AssertionType="Time", Time=token(variable(date_id, "Adjusted Date"))),
    action("dnd.getfocus", UUID=held_id),
    action("gettext", UUID=result_id, WFTextActionText=token(variable(held_id, "Current Focus"), "focus:")),
    action("output", WFOutput=token(variable(result_id, "Text"))),
    action("conditional", GroupingIdentifier=group, WFControlFlowMode=1),
    action("gettext", UUID=blocked_id, WFTextActionText="blocked"),
    action("output", WFOutput=token(variable(blocked_id, "Text"))),
    action("conditional", GroupingIdentifier=group, WFControlFlowMode=2),
]
workflow = {
    "WFWorkflowActions": actions,
    "WFWorkflowClientVersion": "2607.0.2",
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowMinimumClientVersionString": "900",
    "WFWorkflowHasShortcutInputVariables": True,
    "WFWorkflowInputContentItemClasses": ["WFStringContentItem"],
    "WFWorkflowOutputContentItemClasses": ["WFStringContentItem"],
    "WFWorkflowTypes": [], "WFQuickActionSurfaces": [], "WFWorkflowImportQuestions": [],
    "WFWorkflowIcon": {"WFWorkflowIconGlyphNumber": 59432, "WFWorkflowIconStartColor": 4282601983},
}
path = pathlib.Path(__file__).resolve().parent.parent / "build/Hold Calls.unsigned.shortcut"
path.parent.mkdir(exist_ok=True)
path.write_bytes(plistlib.dumps(workflow, fmt=plistlib.FMT_XML))
print(path)
