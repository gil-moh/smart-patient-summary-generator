Include (%AI, %occStatus)

/// Deterministic demos for Smart Patient Summary MVP chunk 1.
Class Sample.AI.Examples.FHIRSummary Extends %RegisteredObject
{

/// Runs GenerateSmartSummary on a fixed patient id and prints JSON.
///
/// Expected environment (set automatically by docker-compose):
///   FHIR_BASE_URL=http://fhir:52773/fhir/r4
///   FHIR_BASIC_USER=_SYSTEM
///   FHIR_BASIC_PASS=SYS
ClassMethod DemoDeterministic(patientId As %String = "a3d599da-a9de-8caa-950a-6bc057b1b261", role As %String = "ed", detailMode As %String = "brief") As %Status
{
    Try {
        Set tool = ##class(Sample.AI.Tools.FHIRReadOnly).%New()
        Set summary = tool.GenerateSmartSummary(patientId, 20, 20, role, detailMode)

        Write !, "=== Smart Patient Summary (Chunk 1) ===", !
        Write "role=", role, !
        Write "detailMode=", detailMode, !
        Write summary.%ToJSON(), !

        Return $$$OK
    } Catch ex {
        Write !, "Demo failed: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Runs all role views for one patient and prints a compact comparison.
ClassMethod DemoRoleComparison(patientId As %String = "a3d599da-a9de-8caa-950a-6bc057b1b261", detailMode As %String = "brief") As %Status
{
    Try {
        Set tool = ##class(Sample.AI.Tools.FHIRReadOnly).%New()
        Set roles = $LISTBUILD("ed", "care_manager", "patient", "caregiver")

        Write !, "=== Smart Patient Summary: Role Comparison ===", !
        Write "patientId=", patientId, !
        Write "detailMode=", detailMode, !

        For i=1:1:$LISTLENGTH(roles) {
            Set role = $LISTGET(roles, i)
            Set summary = tool.GenerateSmartSummary(patientId, 20, 20, role, detailMode)

            If $ISOBJECT(summary) && (summary.%Get("error") '= "") {
                Write !, "[", role, "] error: ", summary.%Get("error"), !
                Continue
            }

            Set sections = summary.%Get("sections")
            Set issues = sections.%Get("currentIssues")
            Set changes = sections.%Get("recentChanges")
            Set risks = sections.%Get("risksFollowUpItems")

            Write !, "[", role, "]", !
            Write "  currentIssues[0]: ", ..GetFirstArrayItem(issues), !
            Write "  recentChanges[0]: ", ..GetFirstArrayItem(changes), !
            Write "  risksFollowUpItems[0]: ", ..GetFirstArrayItem(risks), !
        }

        Return $$$OK
    } Catch ex {
        Write !, "Role comparison failed: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Runs one role summary and prints a clinician-friendly narrative report.
ClassMethod DemoNarrative(patientId As %String = "a3d599da-a9de-8caa-950a-6bc057b1b261", role As %String = "ed", detailMode As %String = "detailed") As %Status
{
    Try {
        Set tool = ##class(Sample.AI.Tools.FHIRReadOnly).%New()
        Set summary = tool.GenerateSmartSummary(patientId, 20, 20, role, detailMode)

        If $ISOBJECT(summary) && (summary.%Get("error") '= "") {
            Write !, "Narrative demo failed: ", summary.%Get("error"), !
            Return $$$ERROR($$$GeneralError, summary.%Get("error"))
        }

        Do ..WriteNarrativeSummary(summary)
        Return $$$OK
    } Catch ex {
        Write !, "Narrative demo failed: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

/// Runs all role views and prints narrative reports for each role.
ClassMethod DemoNarrativeAllRoles(patientId As %String = "a3d599da-a9de-8caa-950a-6bc057b1b261", detailMode As %String = "detailed") As %Status
{
    Try {
        Set tool = ##class(Sample.AI.Tools.FHIRReadOnly).%New()
        Set roles = $LISTBUILD("ed", "care_manager", "patient", "caregiver")

        For i=1:1:$LISTLENGTH(roles) {
            Set role = $LISTGET(roles, i)
            Set summary = tool.GenerateSmartSummary(patientId, 20, 20, role, detailMode)

            If $ISOBJECT(summary) && (summary.%Get("error") '= "") {
                Write !, "[", role, "] error: ", summary.%Get("error"), !
                Continue
            }

            Do ..WriteNarrativeSummary(summary)
            If i < $LISTLENGTH(roles) {
                Write !, "------------------------------------------------------------", !
            }
        }

        Return $$$OK
    } Catch ex {
        Write !, "Narrative all-roles demo failed: ", ex.DisplayString(), !
        Return ex.AsStatus()
    }
}

ClassMethod WriteNarrativeSummary(summary As %DynamicObject) [ Internal ]
{
    Set patientId = ..GetSafeText(summary, "patientId")
    Set role = ..GetSafeText(summary, "role")
    If role = "" {
        Set role = "ed"
    }
    Set detailMode = ..GetSafeText(summary, "detailMode")
    If detailMode = "" {
        Set detailMode = "brief"
    }

    Set raw = summary.%Get("raw")
    Set patient = ""
    Set observations = ""
    Set allergies = ""
    Set conditions = ""
    Set medicationRequests = ""
    Set encounters = ""
    Set carePlans = ""
    If $ISOBJECT(raw) {
        Set patient = raw.%Get("patient")
        Set observations = raw.%Get("observations")
        Set allergies = raw.%Get("allergies")
        Set conditions = raw.%Get("conditions")
        Set medicationRequests = raw.%Get("medicationRequests")
        Set encounters = raw.%Get("encounters")
        Set carePlans = raw.%Get("carePlans")
    }

    Set patientLabel = ..GetPatientLabel(patient, patientId)
    Set gender = ..GetSafeText(patient, "gender")
    Set birthDate = ..GetSafeText(patient, "birthDate")
    Set obsCount = ..GetBundleCount(observations)
    Set allergyCount = ..GetBundleCount(allergies)
    Set conditionCount = ..GetBundleCount(conditions)
    Set medicationCount = ..GetBundleCount(medicationRequests)
    Set encounterCount = ..GetBundleCount(encounters)
    Set carePlanCount = ..GetBundleCount(carePlans)

    Set sections = summary.%Get("sections")
    Set issues = ""
    Set changes = ""
    Set risks = ""
    If $ISOBJECT(sections) {
        Set issues = sections.%Get("currentIssues")
        Set changes = sections.%Get("recentChanges")
        Set risks = sections.%Get("risksFollowUpItems")
    }

    Write !, "Example - Smart Patient Summary", !
    Write !, "Patient Overview", !
    Write "- Patient: ", patientLabel, !
    If (gender '= "") || (birthDate '= "") {
        Write "- Demographics: "
        If gender '= "" {
            Write gender
        }
        If (gender '= "") && (birthDate '= "") {
            Write ", "
        }
        If birthDate '= "" {
            Write "DOB ", birthDate
        }
        Write !
    }
    Write "- Evidence available: problems, medications, allergies, recent encounters, observations, and care plan context.", !

    Write !, "Clinical Details", !
    Do ..WriteTopDetails("Conditions", conditions, "Condition", ..GetDetailLimit(role, "conditions"))
    Do ..WriteTopDetails("Medications", medicationRequests, "MedicationRequest", ..GetDetailLimit(role, "medications"))
    Do ..WriteTopDetails("Allergies", allergies, "AllergyIntolerance", ..GetDetailLimit(role, "allergies"))
    Do ..WriteTopDetails("Recent Encounters", encounters, "Encounter", ..GetDetailLimit(role, "encounters"))
    Do ..WriteTopDetails("Recent Observations", observations, "Observation", ..GetDetailLimit(role, "observations"))
    Do ..WriteUnusualObservationDetails(observations, ..GetDetailLimit(role, "observations"))
    Do ..WriteTopDetails("Care Plans", carePlans, "CarePlan", ..GetDetailLimit(role, "careplans"))

    Write !, "Summary for ", ..RoleTitle(role), !
    Write !, "Current Issues", !
    Do ..WriteDeterministicCurrentIssues(observations, conditions, medicationRequests, allergies, encounters, carePlans)
    Write !, "Recent Changes", !
    Do ..WriteBulletArray(changes, ..GetSectionLimit(role, "changes"))
    Write !, "Risks / Follow-up", !
    Do ..WriteBulletArray(risks, ..GetSectionLimit(role, "risks"))

    Do ..WriteRoleActionPlan(role, observations, medicationRequests, allergies, encounters, carePlans)
}

ClassMethod WriteDeterministicCurrentIssues(observations As %DynamicObject, conditions As %DynamicObject, medicationRequests As %DynamicObject, allergies As %DynamicObject, encounters As %DynamicObject, carePlans As %DynamicObject) [ Internal ]
{
    Set wrote = 0

    If $ISOBJECT(observations) {
        Set obsEntries = observations.%Get("entry")
        If $ISOBJECT(obsEntries) && (obsEntries.%Size()>0) {
            Set maxObs = 3
            Set keptObs = 0
            For i=0:1:(obsEntries.%Size()-1) {
                Quit:keptObs'<maxObs
                Set obsItem = obsEntries.%Get(i)
                If '$ISOBJECT(obsItem) {
                    Continue
                }
                Set obsRes = obsItem.%Get("resource")
                If '$ISOBJECT(obsRes) {
                    Continue
                }
                Set unusual = ..DescribeUnusualObservation(obsRes)
                If unusual = "" {
                    Continue
                }
                Write "- Abnormal observation: ", unusual, !
                Set wrote = 1
                Set keptObs = keptObs + 1
            }
        }
    }

    If $ISOBJECT(conditions) {
        Set condEntries = conditions.%Get("entry")
        If $ISOBJECT(condEntries) && (condEntries.%Size()>0) {
            Set maxCond = 2
            Set keptCond = 0
            For i=0:1:(condEntries.%Size()-1) {
                Quit:keptCond'<maxCond
                Set condItem = condEntries.%Get(i)
                If '$ISOBJECT(condItem) {
                    Continue
                }
                Set condRes = condItem.%Get("resource")
                If '$ISOBJECT(condRes) {
                    Continue
                }
                Set statusText = ..GetCodeFromConcept(condRes.%Get("clinicalStatus"))
                If ..IsInactiveCondition(statusText) {
                    Continue
                }
                Set condText = ..DescribeResource(condRes, "Condition")
                If condText = "" {
                    Continue
                }
                Write "- Active condition: ", condText, !
                Set wrote = 1
                Set keptCond = keptCond + 1
            }
        }
    }

    If $ISOBJECT(medicationRequests) {
        Set medEntries = medicationRequests.%Get("entry")
        If $ISOBJECT(medEntries) && (medEntries.%Size()>0) {
            Set medItem = medEntries.%Get(0)
            If $ISOBJECT(medItem) {
                Set medRes = medItem.%Get("resource")
                Set medText = ..DescribeResource(medRes, "MedicationRequest")
                If medText '= "" {
                    Write "- Active medication context: ", medText, !
                    Set wrote = 1
                }
            }
        }
    }

    If $ISOBJECT(allergies) {
        Set allergyEntries = allergies.%Get("entry")
        If $ISOBJECT(allergyEntries) && (allergyEntries.%Size()>0) {
            Set allergyItem = allergyEntries.%Get(0)
            If $ISOBJECT(allergyItem) {
                Set allergyRes = allergyItem.%Get("resource")
                Set allergyText = ..DescribeResource(allergyRes, "AllergyIntolerance")
                If allergyText '= "" {
                    Write "- Allergy safety constraint: ", allergyText, !
                    Set wrote = 1
                }
            }
        }
    }

    If $ISOBJECT(encounters) {
        Set encEntries = encounters.%Get("entry")
        If $ISOBJECT(encEntries) && (encEntries.%Size()>0) {
            Set encItem = encEntries.%Get(0)
            If $ISOBJECT(encItem) {
                Set encRes = encItem.%Get("resource")
                Set encText = ..DescribeResource(encRes, "Encounter")
                If encText '= "" {
                    Write "- Recent acute utilization: ", encText, !
                    Set wrote = 1
                }
            }
        }
    }

    If $ISOBJECT(carePlans) {
        Set planEntries = carePlans.%Get("entry")
        If $ISOBJECT(planEntries) && (planEntries.%Size()>0) {
            Set planItem = planEntries.%Get(0)
            If $ISOBJECT(planItem) {
                Set planRes = planItem.%Get("resource")
                Set planText = ..DescribeResource(planRes, "CarePlan")
                If planText '= "" {
                    Write "- Active care plan focus: ", planText, !
                    Set wrote = 1
                }
            }
        }
    }

    If 'wrote {
        Write "- No concrete current issues detected in available structured data.", !
    }
}

ClassMethod WriteRoleActionPlan(role As %String, observations As %DynamicObject, medicationRequests As %DynamicObject, allergies As %DynamicObject, encounters As %DynamicObject, carePlans As %DynamicObject) [ Internal ]
{
    If role = "ed" {
        Do ..WriteEDActionPlan(observations, medicationRequests, allergies, encounters)
        Return
    }

    If role = "care_manager" {
        Do ..WriteCareManagerActionPlan(medicationRequests, encounters, carePlans)
        Return
    }

    If role = "patient" {
        Do ..WritePatientActionPlan(observations, medicationRequests, allergies)
        Return
    }

    Do ..WriteCaregiverActionPlan(observations, medicationRequests, allergies, encounters, carePlans)
}

ClassMethod WriteEDActionPlan(observations As %DynamicObject, medicationRequests As %DynamicObject, allergies As %DynamicObject, encounters As %DynamicObject) [ Internal ]
{
    Write !, "Immediate Priorities", !
    Write "- Assess breathing effort, oxygenation, and hemodynamic stability.", !
    Write "- Review recent vitals/labs for acute deterioration patterns.", !
    Write "- Confirm active medications and recent treatment changes.", !

    If ..GetBundleCount(allergies) > 0 {
        Write "- Verify documented allergies before ED medication orders.", !
    }

    Write !, "Before Disposition", !
    Write "- Reconcile key chronic problems and immediate risks in discharge/admit note.", !
    Write "- Ensure follow-up plan is clear and time-bound.", !

    Write !, "Escalate Immediately If", !
    Write "- Worsening dyspnea, unstable vitals, or declining mental status.", !
    Write "- Progressive edema or signs of fluid overload despite therapy.", !

    If ..GetBundleCount(encounters) > 0 {
        Write "- Repeat acute utilization suggests high short-term risk; consider tighter follow-up or admission.", !
    }
}

ClassMethod WriteCareManagerActionPlan(medicationRequests As %DynamicObject, encounters As %DynamicObject, carePlans As %DynamicObject) [ Internal ]
{
    Write !, "Care Coordination Priorities", !
    Write "- Close documentation gaps across medications, encounters, and plan of care.", !
    Write "- Confirm patient understands treatment goals and warning signs.", !

    Write !, "Actions This Week", !
    Write "- Confirm specialist follow-ups and remove scheduling barriers.", !
    Write "- Perform medication reconciliation with pharmacy/clinic records.", !

    If ..GetBundleCount(carePlans) > 0 {
        Write "- Review care plan milestones and assign overdue tasks.", !
    } Else {
        Write "- Create a formal care plan to support cross-team coordination.", !
    }

    Write !, "Escalate to Clinical Team If", !
    Write "- Symptoms worsen between visits or adherence barriers increase.", !
    Write "- Repeated urgent utilization indicates unstable disease control.", !
}

ClassMethod WritePatientActionPlan(observations As %DynamicObject, medicationRequests As %DynamicObject, allergies As %DynamicObject) [ Internal ]
{
    Write !, "What to Do Today", !
    Write "- Take medications exactly as prescribed.", !
    Write "- Monitor breathing, swelling, and energy level.", !
    Write "- Track weight daily and note sudden changes.", !

    Write !, "This Week", !
    Write "- Keep follow-up appointments and bring your medication list.", !
    Write "- Ask your care team to clarify any unclear medication or plan instructions.", !

    If ..GetBundleCount(allergies) > 0 {
        Write "- Remind every clinician/pharmacist about your documented allergy history.", !
    }

    Write !, "Call Your Care Team Now If", !
    Write "- Breathing gets worse, swelling increases, or you feel faint/confused.", !
    Write "- You have side effects after a medication change.", !
}

ClassMethod WriteCaregiverActionPlan(observations As %DynamicObject, medicationRequests As %DynamicObject, allergies As %DynamicObject, encounters As %DynamicObject, carePlans As %DynamicObject) [ Internal ]
{
    Write !, "What to Monitor Daily", !
    Write "- Check breathing effort and whether shortness of breath is worsening.", !
    Write "- Track leg swelling and compare with prior days.", !
    Write "- Track weight daily; rapid gain may indicate fluid retention.", !
    Write "- Confirm medications were taken as prescribed.", !

    If ..GetBundleCount(medicationRequests) = 0 {
        Write "- Medication list appears incomplete in FHIR; confirm active medications with care team.", !
    }

    If ..GetBundleCount(allergies) > 0 {
        Write "- Keep known allergies visible before any medication changes.", !
    }

    Write !, "Actions This Week", !
    Write "- Review upcoming appointments and help with scheduling/logistics.", !
    Write "- Bring an updated medication list to the next visit.", !
    Write "- Share recent symptom and weight trends with the care team.", !

    If ..GetBundleCount(carePlans) > 0 {
        Write "- Review care plan goals and overdue actions.", !
    } Else {
        Write "- Ask whether a formal care plan should be added for coordination.", !
    }

    Write !, "Call the Care Team Urgently If", !
    Write "- Breathing is worsening, especially at rest.", !
    Write "- Weight rises quickly over a short period.", !
    Write "- Marked new swelling, dizziness, confusion, or unusual weakness appears.", !

    If ..GetBundleCount(encounters) > 0 {
        Write "- Symptoms are worsening despite recent encounters or treatment changes.", !
    }
}

ClassMethod WriteTopDetails(label As %String, bundle As %DynamicObject, resourceType As %String, maxItems As %Integer = 3) [ Internal ]
{
    If '$ISOBJECT(bundle) {
        Write "- ", label, ": (none)", !
        Return
    }

    Set entries = bundle.%Get("entry")
    If '$ISOBJECT(entries) || (entries.%Size()=0) {
        Write "- ", label, ": (none)", !
        Return
    }

    Set cap = $SELECT(maxItems<1:1, 1:maxItems)
    Set out = ""
    For i=0:1:(entries.%Size()-1) {
        Quit:i'<cap
        Set item = entries.%Get(i)
        If '$ISOBJECT(item) {
            Continue
        }
        Set resource = item.%Get("resource")
        Set one = ..DescribeResource(resource, resourceType)
        If one = "" {
            Continue
        }

        If out = "" {
            Set out = one
        } Else {
            Set out = out _ "; " _ one
        }
    }

    If out = "" {
        Set out = "(none)"
    }
    Write "- ", label, ": ", out, !
}

ClassMethod DescribeResource(resource As %DynamicObject, resourceType As %String) As %String [ Internal ]
{
    If '$ISOBJECT(resource) {
        Return ""
    }

    If resourceType = "Condition" {
        Set codeText = ..GetCodeableConceptDisplay(resource.%Get("code"))
        Set statusText = ..GetCodeFromConcept(resource.%Get("clinicalStatus"))
        Set diagnosedOn = ..GetConditionDate(resource)
        Set inactiveOn = ..GetConditionInactiveDate(resource)
        If codeText = "" {
            Set codeText = "Condition"
        }
        If ..IsInactiveCondition(statusText) {
            Set timeline = "inactive"
            If diagnosedOn '= "" {
                Set timeline = timeline _ ", diagnosed " _ diagnosedOn
            }
            If inactiveOn '= "" {
                Set timeline = timeline _ ", inactive since " _ inactiveOn
            } Else {
                Set timeline = timeline _ ", inactive date not recorded"
            }
            Return codeText _ " (" _ timeline _ ")"
        }
        If (statusText '= "") && (diagnosedOn '= "") {
            Return codeText _ " (" _ statusText _ ", diagnosed " _ diagnosedOn _ ")"
        }
        If statusText '= "" {
            Return codeText _ " (" _ statusText _ ")"
        }
        If diagnosedOn '= "" {
            Return codeText _ " (diagnosed " _ diagnosedOn _ ")"
        }
        Return codeText
    }

    If resourceType = "MedicationRequest" {
        Set med = ..GetCodeableConceptDisplay(resource.%Get("medicationCodeableConcept"))
        If med = "" {
            Set med = "Medication request"
        }
        Set authoredOn = ..GetSafeText(resource, "authoredOn")
        If authoredOn '= "" {
            Return med _ " (authored " _ authoredOn _ ")"
        }
        Return med
    }

    If resourceType = "AllergyIntolerance" {
        Set substance = ..GetCodeableConceptDisplay(resource.%Get("code"))
        If substance = "" {
            Set substance = "Allergy/intolerance"
        }
        Set reactionText = ..GetAllergyReaction(resource)
        If reactionText '= "" {
            Return substance _ " (reaction: " _ reactionText _ ")"
        }
        Return substance
    }

    If resourceType = "Encounter" {
        Set encType = ..GetFirstCodingDisplayFromArray(resource.%Get("type"))
        If encType = "" {
            Set encType = "Encounter"
        }
        Set period = resource.%Get("period")
        Set startDate = ..GetSafeText(period, "start")
        Set reason = ..GetEncounterReason(resource)
        Set suffix = ""
        If startDate '= "" {
            Set suffix = startDate
        }
        If reason '= "" {
            If suffix '= "" {
                Set suffix = suffix _ "; "
            }
            Set suffix = suffix _ "reason: " _ reason
        }
        If suffix = "" {
            Return encType
        }
        Return encType _ " (" _ suffix _ ")"
    }

    If resourceType = "Observation" {
        Set obsName = ..GetCodeableConceptDisplay(resource.%Get("code"))
        If obsName = "" {
            Set obsName = "Observation"
        }
        Set valueText = ..GetObservationValue(resource)
        If valueText '= "" {
            Return obsName _ "=" _ valueText
        }
        Return obsName
    }

    If resourceType = "CarePlan" {
        Set title = ..GetSafeText(resource, "title")
        If title '= "" {
            Return title
        }
        Set desc = ..GetSafeText(resource, "description")
        If desc '= "" {
            Return desc
        }
        Return "Care plan"
    }

    Return ""
}

ClassMethod GetCodeableConceptDisplay(codeableConcept As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(codeableConcept) {
        Return ""
    }

    Set text = ..GetSafeText(codeableConcept, "text")
    If text '= "" {
        Return text
    }

    Set coding = codeableConcept.%Get("coding")
    If $ISOBJECT(coding) && (coding.%Size()>0) {
        Set c0 = coding.%Get(0)
        If $ISOBJECT(c0) {
            Set display = ..GetSafeText(c0, "display")
            If display '= "" {
                Return display
            }
            Set code = ..GetSafeText(c0, "code")
            If code '= "" {
                Return code
            }
        }
    }

    Return ""
}

ClassMethod GetCodeFromConcept(concept As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(concept) {
        Return ""
    }

    Set coding = concept.%Get("coding")
    If $ISOBJECT(coding) && (coding.%Size()>0) {
        Set c0 = coding.%Get(0)
        If $ISOBJECT(c0) {
            Set display = ..GetSafeText(c0, "display")
            If display '= "" {
                Return display
            }
            Return ..GetSafeText(c0, "code")
        }
    }
    Return ""
}

ClassMethod GetFirstCodingDisplayFromArray(typeArr As %DynamicArray) As %String [ Internal ]
{
    If '$ISOBJECT(typeArr) || (typeArr.%Size()=0) {
        Return ""
    }

    Set t0 = typeArr.%Get(0)
    If '$ISOBJECT(t0) {
        Return ""
    }
    Return ..GetCodeableConceptDisplay(t0)
}

ClassMethod GetAllergyReaction(allergy As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(allergy) {
        Return ""
    }

    Set reactions = allergy.%Get("reaction")
    If '$ISOBJECT(reactions) || (reactions.%Size()=0) {
        Return ""
    }

    Set r0 = reactions.%Get(0)
    If '$ISOBJECT(r0) {
        Return ""
    }

    Set manifests = r0.%Get("manifestation")
    If '$ISOBJECT(manifests) || (manifests.%Size()=0) {
        Return ""
    }

    Set m0 = manifests.%Get(0)
    If '$ISOBJECT(m0) {
        Return ""
    }

    Return ..GetCodeableConceptDisplay(m0)
}

ClassMethod GetObservationValue(observation As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(observation) {
        Return ""
    }

    Set q = observation.%Get("valueQuantity")
    If $ISOBJECT(q) {
        Set v = ..GetSafeText(q, "value")
        Set u = ..GetSafeText(q, "unit")
        Set text = $ZSTRIP(v _ " " _ u, "<>W")
        If text '= "" {
            Return text
        }
    }

    Set valueString = ..GetSafeText(observation, "valueString")
    If valueString '= "" {
        Return valueString
    }

    Return ""
}

ClassMethod WriteUnusualObservationDetails(bundle As %DynamicObject, maxItems As %Integer = 3) [ Internal ]
{
    If '$ISOBJECT(bundle) {
        Quit
    }

    Set entries = bundle.%Get("entry")
    If '$ISOBJECT(entries) || (entries.%Size()=0) {
        Quit
    }

    Set cap = $SELECT(maxItems<1:1, 1:maxItems)
    Set out = ""
    Set kept = 0
    For i=0:1:(entries.%Size()-1) {
        Quit:kept'<cap
        Set item = entries.%Get(i)
        If '$ISOBJECT(item) {
            Continue
        }
        Set resource = item.%Get("resource")
        If '$ISOBJECT(resource) {
            Continue
        }

        Set unusual = ..DescribeUnusualObservation(resource)
        If unusual = "" {
            Continue
        }

        If out = "" {
            Set out = unusual
        } Else {
            Set out = out _ "; " _ unusual
        }
        Set kept = kept + 1
    }

    If out '= "" {
        Write "- Unusual Results: ", out, !
    }
}

ClassMethod DescribeUnusualObservation(observation As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(observation) {
        Return ""
    }

    Set obsName = ..GetCodeableConceptDisplay(observation.%Get("code"))
    If obsName = "" {
        Set obsName = "Observation"
    }

    Set valueText = ..GetObservationValue(observation)
    If valueText = "" {
        Return ""
    }

    Set q = observation.%Get("valueQuantity")
    Set valueRaw = ""
    Set unit = ""
    Set hasNumeric = 0
    Set valueNum = 0
    If $ISOBJECT(q) {
        Set valueRaw = ..GetSafeText(q, "value")
        Set unit = ..GetSafeText(q, "unit")
        If ..IsNumericText(valueRaw) {
            Set hasNumeric = 1
            Set valueNum = +valueRaw
        }
    }

    Set flag = ""
    Set detail = ""

    Set rr = observation.%Get("referenceRange")
    If $ISOBJECT(rr) && (rr.%Size()>0) && hasNumeric {
        Set rr0 = rr.%Get(0)
        If $ISOBJECT(rr0) {
            Set lowObj = rr0.%Get("low")
            Set highObj = rr0.%Get("high")
            Set lowRaw = ""
            Set highRaw = ""
            If $ISOBJECT(lowObj) {
                Set lowRaw = ..GetSafeText(lowObj, "value")
            }
            If $ISOBJECT(highObj) {
                Set highRaw = ..GetSafeText(highObj, "value")
            }

            If (lowRaw '= "") && ..IsNumericText(lowRaw) && (valueNum < +lowRaw) {
                Set flag = "low"
            }
            If (highRaw '= "") && ..IsNumericText(highRaw) && (valueNum > +highRaw) {
                Set flag = "high"
            }

            If flag '= "" {
                Set rrText = ""
                If lowRaw '= "" {
                    Set rrText = lowRaw
                }
                If highRaw '= "" {
                    If rrText '= "" {
                        Set rrText = rrText _ "-"
                    }
                    Set rrText = rrText _ highRaw
                }
                If rrText '= "" {
                    Set detail = flag
                } Else {
                    Set detail = flag _ " vs reference " _ rrText
                    If unit '= "" {
                        Set detail = detail _ " " _ unit
                    }
                }
            }
        }
    }

    If detail = "" {
        Set interp = ..GetObservationInterpretationFlag(observation)
        If interp '= "" {
            Set detail = interp
            Set flag = interp
        }
    }

    If detail = "" {
        Set thresh = ..GetObservationThresholdFlag(obsName, hasNumeric, valueNum)
        If thresh '= "" {
            Set detail = thresh _ " (rule-based threshold)"
            Set flag = thresh
        }
    }

    If detail = "" {
        Return ""
    }

    Return obsName _ "=" _ valueText _ " [" _ detail _ "]"
}

ClassMethod GetObservationInterpretationFlag(observation As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(observation) {
        Return ""
    }

    Set interp = observation.%Get("interpretation")
    If '$ISOBJECT(interp) || (interp.%Size()=0) {
        Return ""
    }

    Set c0 = interp.%Get(0)
    If '$ISOBJECT(c0) {
        Return ""
    }

    Set codings = c0.%Get("coding")
    If $ISOBJECT(codings) && (codings.%Size()>0) {
        Set firstCoding = codings.%Get(0)
        If $ISOBJECT(firstCoding) {
            Set code = $ZCONVERT(..GetSafeText(firstCoding, "code"), "L")
            If (code = "h") || (code = "hh") || (code = "hu") || (code = "crit") {
                Return "high"
            }
            If (code = "l") || (code = "ll") || (code = "lu") {
                Return "low"
            }
            If (code = "a") || (code = "abnormal") {
                Return "abnormal"
            }
        }
    }

    Set txt = $ZCONVERT(..GetCodeableConceptDisplay(c0), "L")
    If (txt [ "high") || (txt [ "critical") {
        Return "high"
    }
    If txt [ "low" {
        Return "low"
    }
    If txt [ "abnormal" {
        Return "abnormal"
    }

    Return ""
}

ClassMethod GetObservationThresholdFlag(obsName As %String, hasNumeric As %Boolean, valueNum As %Double) As %String [ Internal ]
{
    If 'hasNumeric {
        Return ""
    }

    Set name = $ZCONVERT(obsName, "L")

    If (name [ "systolic") && (name [ "blood pressure") {
        If valueNum < 90 Return "low"
        If valueNum > 180 Return "high"
        Return ""
    }

    If (name [ "diastolic") && (name [ "blood pressure") {
        If valueNum < 60 Return "low"
        If valueNum > 120 Return "high"
        Return ""
    }

    If (name [ "heart rate") || (name [ "pulse rate") {
        If valueNum < 50 Return "low"
        If valueNum > 120 Return "high"
        Return ""
    }

    If (name [ "oxygen saturation") || (name [ "spo2") {
        If valueNum < 92 Return "low"
        Return ""
    }

    If name [ "temperature" {
        If valueNum < 35 Return "low"
        If valueNum > 38.3 Return "high"
        Return ""
    }

    If name [ "respiratory rate" {
        If valueNum < 10 Return "low"
        If valueNum > 24 Return "high"
        Return ""
    }

    If name [ "glucose" {
        If valueNum < 70 Return "low"
        If valueNum > 250 Return "high"
        Return ""
    }

    Return ""
}

ClassMethod IsNumericText(raw As %String) As %Boolean [ Internal ]
{
    Set t = $ZSTRIP(raw, "<W")
    If t = "" {
        Return 0
    }

    If t?1(1"+",1"-").N {
        Return 1
    }
    If t?1(1"+",1"-").N1"."1.N {
        Return 1
    }
    If t?1.N {
        Return 1
    }
    If t?1.N1"."1.N {
        Return 1
    }

    Return 0
}

ClassMethod GetConditionDate(condition As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(condition) {
        Return ""
    }

    Set onset = ..GetSafeText(condition, "onsetDateTime")
    If onset '= "" {
        Return onset
    }

    Set recorded = ..GetSafeText(condition, "recordedDate")
    If recorded '= "" {
        Return recorded
    }

    Return ""
}

ClassMethod GetConditionInactiveDate(condition As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(condition) {
        Return ""
    }

    Set inactive = ..GetSafeText(condition, "abatementDateTime")
    If inactive '= "" {
        Return inactive
    }

    Set p = condition.%Get("abatementPeriod")
    If $ISOBJECT(p) {
        Set inactive = ..GetSafeText(p, "end")
        If inactive '= "" {
            Return inactive
        }
    }

    Return ""
}

ClassMethod IsInactiveCondition(statusText As %String) As %Boolean [ Internal ]
{
    Set s = $ZCONVERT($ZSTRIP(statusText, "<>W"), "L")
    If (s = "inactive") || (s = "resolved") || (s = "remission") {
        Return 1
    }
    Return 0
}

ClassMethod GetEncounterReason(encounter As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(encounter) {
        Return ""
    }

    Set reasons = encounter.%Get("reasonCode")
    If $ISOBJECT(reasons) && (reasons.%Size() > 0) {
        Set r0 = reasons.%Get(0)
        If $ISOBJECT(r0) {
            Set reason = ..GetCodeableConceptDisplay(r0)
            If reason '= "" {
                Return reason
            }
        }
    }

    Return ""
}

ClassMethod WriteBulletArray(arr As %DynamicArray, maxItems As %Integer = 999) [ Internal ]
{
    If '$ISOBJECT(arr) || (arr.%Size()=0) {
        Write "- (none)", !
        Return
    }

    Set cap = $SELECT(maxItems<1:1, 1:maxItems)
    Set kept = 0
    For i=0:1:(arr.%Size()-1) {
        Quit:kept'<cap
        Set one = ..GetArrayText(arr, i)
        If $EXTRACT(one, 1, 14) = "Detailed view:" {
            Continue
        }
        Do ..WriteWrappedBullet(one)
        Set kept = kept + 1
    }
}

ClassMethod GetSectionLimit(role As %String, section As %String) As %Integer [ Internal ]
{
    // Do not exclude narrative data by role.
    Return 999
}

ClassMethod GetDetailLimit(role As %String, detailKind As %String) As %Integer [ Internal ]
{
    // Do not exclude clinical details by role.
    Return 999
}

ClassMethod WriteWrappedBullet(text As %String, maxLen As %Integer = 72) [ Internal ]
{
    Set line = $ZSTRIP(text, "<>W")
    If line = "" {
        Write "- (none)", !
        Return
    }

    Set first = 1
    Set width = $SELECT(maxLen<40:40, 1:maxLen)

    While 1 {
        If $L(line) <= width {
            If first {
                Write "- ", line, !
            } Else {
                Write "  ", line, !
            }
            Quit
        }

        Set segment = $E(line, 1, width)
        Set cut = width
        For i=width:-1:1 {
            If $E(segment, i) = " " {
                Set cut = i
                Quit
            }
        }
        If cut < 10 {
            Set cut = width
        }

        Set part = $ZSTRIP($E(line, 1, cut), "<>W")
        If first {
            Write "- ", part, !
            Set first = 0
        } Else {
            Write "  ", part, !
        }

        Set line = $ZSTRIP($E(line, cut+1, $L(line)), "<>W")
    }
}

ClassMethod GetPatientLabel(patient As %DynamicObject, fallbackId As %String = "") As %String [ Internal ]
{
    If $ISOBJECT(patient) {
        Set names = patient.%Get("name")
        If $ISOBJECT(names) && (names.%Size()>0) {
            Set n = names.%Get(0)
            If $ISOBJECT(n) {
                Set text = ..GetSafeText(n, "text")
                If text '= "" {
                    Return text
                }

                Set given = ""
                Set givens = n.%Get("given")
                If $ISOBJECT(givens) && (givens.%Size() > 0) {
                    Set given = ..GetArrayText(givens, 0)
                }
                Set family = ..GetSafeText(n, "family")
                Set full = $ZSTRIP(given _ " " _ family, "<>W")
                If full '= "" {
                    Return full
                }
            }
        }

        Set pid = ..GetSafeText(patient, "id")
        If pid '= "" {
            Return "Patient " _ pid
        }
    }

    If fallbackId '= "" {
        Return "Patient " _ fallbackId
    }
    Return "Unknown patient"
}

ClassMethod GetSafeText(obj As %DynamicObject, key As %String) As %String [ Internal ]
{
    If '$ISOBJECT(obj) {
        Return ""
    }

    Try {
        Set value = obj.%Get(key)
        Return value
    } Catch ex {
        Return ""
    }
}

ClassMethod GetBundleCount(bundle As %DynamicObject) As %Integer [ Internal ]
{
    If '$ISOBJECT(bundle) {
        Return 0
    }

    Set entries = bundle.%Get("entry")
    If $ISOBJECT(entries) {
        Return entries.%Size()
    }

    Try {
        Return +$GET(bundle.%Get("total"), 0)
    } Catch ex {
        Return 0
    }
}

ClassMethod GetArrayText(arr As %DynamicArray, idx As %Integer) As %String [ Internal ]
{
    If '$ISOBJECT(arr) {
        Return ""
    }

    Try {
        Set value = arr.%Get(idx)
        Return value
    } Catch ex {
        Return ""
    }
}

ClassMethod RoleTitle(role As %String) As %String [ Internal ]
{
    If role = "ed" Return "ED Doctor"
    If role = "care_manager" Return "Care Manager"
    If role = "patient" Return "Patient"
    If role = "caregiver" Return "Family Caregiver"
    Return role
}

ClassMethod GetFirstArrayItem(arr As %DynamicArray) As %String [ Internal ]
{
    If '$ISOBJECT(arr) {
        Return "(none)"
    }

    If arr.%Size() = 0 {
        Return "(none)"
    }

    Try {
        Set item = arr.%Get(0)
    } Catch ex {
        Return "(none)"
    }

    If item = "" {
        Return "(none)"
    }

    Return item
}

/// Runs one role summary and writes only clinician-facing narrative text to a file.
/// This avoids terminal/session scaffolding like USER> prompts in shared artifacts.
ClassMethod DemoNarrativeToFile(patientId As %String = "a3d599da-a9de-8caa-950a-6bc057b1b261", role As %String = "ed", detailMode As %String = "detailed", outputPath As %String = "/tmp/smart-summary.txt") As %Status
{
    Set oldIO = $IO
    Set opened = 0
    Try {
        Open outputPath:"NWS":5
        If '$TEST {
            Return $$$ERROR($$$GeneralError, "Unable to open output file: " _ outputPath)
        }
        Set opened = 1
        Use outputPath

        Set tool = ##class(Sample.AI.Tools.FHIRReadOnly).%New()
        Set summary = tool.GenerateSmartSummary(patientId, 20, 20, role, detailMode)

        If $ISOBJECT(summary) && (summary.%Get("error") '= "") {
            Write "Narrative demo failed: ", summary.%Get("error"), !
            Use oldIO
            Close outputPath
            Return $$$ERROR($$$GeneralError, summary.%Get("error"))
        }

        Do ..WriteNarrativeSummary(summary)

        Use oldIO
        Close outputPath
        Return $$$OK
    } Catch ex {
        If $IO '= oldIO {
            Use oldIO
        }
        If opened {
            Close outputPath
        }
        Return ex.AsStatus()
    }
}

}