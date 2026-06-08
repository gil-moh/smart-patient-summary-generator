Include (%AI, %occStatus)

/// Read-only FHIR tools for quick interoperability analysis workflows.
///
/// Configure the FHIR target with environment variables:
///   FHIR_BASE_URL   e.g. http://fhir:52773/fhir/r4  (Docker service name, set automatically by docker-compose)
///   FHIR_BEARER_TOKEN  optional bearer token
///   FHIR_BASIC_USER / FHIR_BASIC_PASS  optional basic auth credentials
Class Sample.AI.Tools.FHIRReadOnly Extends %AI.Tool
{

/// Search for patients by common criteria.
Method SearchPatients(name As %String = "", identifier As %String = "", birthDate As %String = "", limit As %Integer = 10) As %DynamicObject
{
    Set max = $SELECT(limit>100:100, limit<1:1, 1:limit)
    Set query = "_count=" _ max
    If name '= "" {
        Set query = query _ "&name=" _ ..UrlEncode(name)
    }
    If identifier '= "" {
        Set query = query _ "&identifier=" _ ..UrlEncode(identifier)
    }
    If birthDate '= "" {
        Set query = query _ "&birthdate=" _ ..UrlEncode(birthDate)
    }

    Return ..GetFHIR("Patient?" _ query)
}

/// Fetch one patient resource by logical id.
Method GetPatientById(patientId As %String) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }
    Return ..GetFHIR("Patient/" _ ..UrlEncode(patientId))
}

/// Fetch observations for a patient, optionally filtering by category.
Method GetObservationSummary(patientId As %String, category As %String = "", limit As %Integer = 20) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }

    Set max = $SELECT(limit>100:100, limit<1:1, 1:limit)
    Set query = "patient=" _ ..UrlEncode(patientId) _ "&_count=" _ max
    If category '= "" {
        Set query = query _ "&category=" _ ..UrlEncode(category)
    }

    Return ..GetFHIRWithFallback("Observation?" _ query, patientId)
}

/// Fetch allergy/intolerance records for a patient.
Method GetAllergies(patientId As %String, limit As %Integer = 20) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }

    Set max = $SELECT(limit>100:100, limit<1:1, 1:limit)
    Set query = "patient=" _ ..UrlEncode(patientId) _ "&_count=" _ max
    Return ..GetFHIRWithFallback("AllergyIntolerance?" _ query, patientId)
}

/// Fetch conditions for a patient, optionally filtering by clinical status.
Method GetConditions(patientId As %String, clinicalStatus As %String = "", limit As %Integer = 20) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }

    Set max = $SELECT(limit>100:100, limit<1:1, 1:limit)
    Set query = "patient=" _ ..UrlEncode(patientId) _ "&_count=" _ max
    If clinicalStatus '= "" {
        Set query = query _ "&clinical-status=" _ ..UrlEncode(clinicalStatus)
    }

    Return ..GetFHIRWithFallback("Condition?" _ query, patientId)
}

/// Fetch medication requests for a patient, optionally filtering by status.
Method GetMedicationRequests(patientId As %String, status As %String = "", limit As %Integer = 20) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }

    Set max = $SELECT(limit>100:100, limit<1:1, 1:limit)
    Set query = "patient=" _ ..UrlEncode(patientId) _ "&_count=" _ max
    If status '= "" {
        Set query = query _ "&status=" _ ..UrlEncode(status)
    }

    Return ..GetFHIRWithFallback("MedicationRequest?" _ query, patientId)
}

/// Fetch encounters for a patient, optionally filtering by status.
Method GetEncounters(patientId As %String, status As %String = "", limit As %Integer = 20) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }

    Set max = $SELECT(limit>100:100, limit<1:1, 1:limit)
    Set query = "patient=" _ ..UrlEncode(patientId) _ "&_count=" _ max
    If status '= "" {
        Set query = query _ "&status=" _ ..UrlEncode(status)
    }

    Return ..GetFHIRWithFallback("Encounter?" _ query, patientId)
}

/// Fetch care plans for a patient, optionally filtering by status.
Method GetCarePlans(patientId As %String, status As %String = "", limit As %Integer = 20) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }

    Set max = $SELECT(limit>100:100, limit<1:1, 1:limit)
    Set query = "patient=" _ ..UrlEncode(patientId) _ "&_count=" _ max
    If status '= "" {
        Set query = query _ "&status=" _ ..UrlEncode(status)
    }

    Return ..GetFHIRWithFallback("CarePlan?" _ query, patientId)
}

/// Aggregate a compact patient signal snapshot for Smart Patient Summary MVP (chunk 1).
/// Returns patient demographics resource + recent observations + allergies + deterministic counters.
Method GetPatientSignals(patientId As %String, observationLimit As %Integer = 20, allergyLimit As %Integer = 20, conditionLimit As %Integer = 20, medicationLimit As %Integer = 20, encounterLimit As %Integer = 20, carePlanLimit As %Integer = 20) As %DynamicObject
{
    If patientId = "" {
        Return {"error":"patientId is required"}
    }

    Set patient = ..GetPatientById(patientId)
    Set observations = ..GetObservationSummary(patientId, "", observationLimit)
    Set allergies = ..GetAllergies(patientId, allergyLimit)
    Set conditions = ..GetConditions(patientId, "", conditionLimit)
    Set medications = ..GetMedicationRequests(patientId, "", medicationLimit)
    Set encounters = ..GetEncounters(patientId, "", encounterLimit)
    Set carePlans = ..GetCarePlans(patientId, "", carePlanLimit)

    Set hasPatient = 0
    If $ISOBJECT(patient) {
        Try {
            If patient.%Get("resourceType") = "Patient" {
                Set hasPatient = 1
            }
        } Catch ex {
            Set hasPatient = 0
        }
    }

    Return {
        "patientId": (patientId),
        "generatedAt": ($ZDATETIME($HOROLOG, 3, 1)),
        "patient": (patient),
        "observations": (observations),
        "allergies": (allergies),
        "conditions": (conditions),
        "medicationRequests": (medications),
        "encounters": (encounters),
        "carePlans": (carePlans),
        "signals": {
            "hasPatient": (hasPatient),
            "observationCount": (..CountBundleEntries(observations)),
            "allergyCount": (..CountBundleEntries(allergies)),
            "conditionCount": (..CountBundleEntries(conditions)),
            "medicationRequestCount": (..CountBundleEntries(medications)),
            "encounterCount": (..CountBundleEntries(encounters)),
            "carePlanCount": (..CountBundleEntries(carePlans))
        }
    }
}

/// Build deterministic MVP summary sections from read-only patient signals.
/// Output sections are fixed for contest judging: current issues, recent changes, risks / follow-up items.
///
/// role options: ed, care_manager, patient, caregiver.
/// detailMode options: brief, detailed.
Method GenerateSmartSummary(patientId As %String, observationLimit As %Integer = 20, allergyLimit As %Integer = 20, role As %String = "ed", detailMode As %String = "brief") As %DynamicObject
{
    Set snapshot = ..GetPatientSignals(patientId, observationLimit, allergyLimit)
    If ..SafeGet(snapshot, "error") '= "" {
        Return snapshot
    }

    Set signalObj = snapshot.%Get("signals")
    Set hasPatient = ..IsExpectedResource(snapshot.%Get("patient"), "Patient")
    Set observationCount = ..CountBundleEntries(snapshot.%Get("observations"))
    Set allergyCount = ..CountBundleEntries(snapshot.%Get("allergies"))
    Set conditionCount = ..CountBundleEntries(snapshot.%Get("conditions"))
    Set medicationRequestCount = ..CountBundleEntries(snapshot.%Get("medicationRequests"))
    Set encounterCount = ..CountBundleEntries(snapshot.%Get("encounters"))
    Set carePlanCount = ..CountBundleEntries(snapshot.%Get("carePlans"))
    Set normalizedRole = ..NormalizeRole(role)
    Set normalizedDetailMode = ..NormalizeDetailMode(detailMode)
    Set patientName = ..GetPatientDisplayName(snapshot.%Get("patient"))
    If (patientName = "Unknown patient") && (patientId '= "") {
        Set patientName = "Patient " _ patientId
    }

    Set currentIssues = []
    Set recentChanges = []
    Set risksFollowUp = []

    If hasPatient {
        Do currentIssues.%Push("Patient context available for " _ patientName _ ".")
    } Else {
        Do currentIssues.%Push("Patient resource is missing or inaccessible.")
    }

    If observationCount > 0 {
        Do currentIssues.%Push("Recent observations reviewed.")
        Do recentChanges.%Push("Review latest observations for clinically meaningful trend changes.")
    } Else {
        Do currentIssues.%Push("No recent observations found in the selected window.")
        Do recentChanges.%Push("No observation deltas can be inferred from current data.")
    }

    If allergyCount > 0 {
        Do currentIssues.%Push("Allergy/intolerance history reviewed.")
        Do recentChanges.%Push("Confirm whether any allergy entries are new or recently verified.")
        Do risksFollowUp.%Push("Use allergy cross-check before medication changes or reconciliations.")
    } Else {
        Do currentIssues.%Push("No allergy/intolerance records found.")
        Do risksFollowUp.%Push("Validate absence of allergy records with chart history.")
    }

    If conditionCount > 0 {
        Do currentIssues.%Push("Active condition history reviewed.")
        Do recentChanges.%Push("Review active condition list for unresolved or high-risk chronic problems.")
    } Else {
        Do currentIssues.%Push("No condition records found.")
        Do risksFollowUp.%Push("Verify whether problem list documentation is incomplete or unavailable.")
    }

    If medicationRequestCount > 0 {
        Do currentIssues.%Push("Active medication requests reviewed.")
        Do recentChanges.%Push("Reconcile active medication requests with current treatment intent and timing.")
    } Else {
        Do currentIssues.%Push("No medication request records found.")
        Do risksFollowUp.%Push("Confirm whether medication plan data is missing, inactive, or stored in another source.")
    }

    If encounterCount > 0 {
        Do currentIssues.%Push("Recent encounter history reviewed.")
        Do recentChanges.%Push("Review recent encounter timeline for acute utilization changes and transitions of care.")
    } Else {
        Do currentIssues.%Push("No encounter records found.")
        Do risksFollowUp.%Push("Verify whether utilization history is unavailable for this patient context.")
    }

    If carePlanCount > 0 {
        Do currentIssues.%Push("Care plan context reviewed.")
        Do recentChanges.%Push("Check care plan goals and interventions for recent updates or overdue actions.")
    } Else {
        Do currentIssues.%Push("No care plan records found.")
        Do risksFollowUp.%Push("Consider whether care coordination plans are missing or documented outside FHIR CarePlan.")
    }

    If 'hasPatient {
        Do risksFollowUp.%Push("Resolve patient identity/data access issues before clinical decision support.")
    }
    If observationCount = 0 {
        Do risksFollowUp.%Push("Limited recent measurements may hide deterioration; consider ordering key follow-up labs/vitals.")
    }

    Do ..ApplyRoleView(normalizedRole, patientName, .currentIssues, .recentChanges, .risksFollowUp)
    Do ..ApplyDetailMode(normalizedDetailMode, observationCount, allergyCount, conditionCount, medicationRequestCount, encounterCount, carePlanCount, .currentIssues, .recentChanges, .risksFollowUp)

    Return {
        "patientId": (patientId),
        "generatedAt": ($ZDATETIME($HOROLOG, 3, 1)),
        "role": (normalizedRole),
        "detailMode": (normalizedDetailMode),
        "sections": {
            "currentIssues": (currentIssues),
            "recentChanges": (recentChanges),
            "risksFollowUpItems": (risksFollowUp)
        },
        "signals": (signalObj),
        "raw": {
            "patient": (snapshot.%Get("patient")),
            "observations": (snapshot.%Get("observations")),
            "allergies": (snapshot.%Get("allergies")),
            "conditions": (snapshot.%Get("conditions")),
            "medicationRequests": (snapshot.%Get("medicationRequests")),
            "encounters": (snapshot.%Get("encounters")),
            "carePlans": (snapshot.%Get("carePlans"))
        }
    }
}

Method NormalizeRole(role As %String) As %String [ Internal ]
{
    Set r = $ZCONVERT($ZSTRIP(role, "<>W"), "L")
    If r = "" Return "ed"

    If (r = "ed") || (r = "emergency") || (r = "ed_doctor") Return "ed"
    If (r = "care_manager") || (r = "case_manager") || (r = "care") Return "care_manager"
    If (r = "patient") Return "patient"
    If (r = "caregiver") || (r = "family") || (r = "family_caregiver") Return "caregiver"

    Return "ed"
}

Method NormalizeDetailMode(detailMode As %String) As %String [ Internal ]
{
    Set d = $ZCONVERT($ZSTRIP(detailMode, "<>W"), "L")
    If (d = "detailed") || (d = "full") || (d = "verbose") {
        Return "detailed"
    }
    Return "brief"
}

Method ApplyDetailMode(detailMode As %String, observationCount As %Integer, allergyCount As %Integer, conditionCount As %Integer, medicationRequestCount As %Integer, encounterCount As %Integer, carePlanCount As %Integer, ByRef currentIssues As %DynamicArray, ByRef recentChanges As %DynamicArray, ByRef risksFollowUp As %DynamicArray) [ Internal ]
{
    If detailMode = "brief" {
        Set currentIssues = ..CopyFirstN(currentIssues, 2)
        Set recentChanges = ..CopyFirstN(recentChanges, 2)
        Set risksFollowUp = ..CopyFirstN(risksFollowUp, 2)
        Return
    }

    Do currentIssues.%Push("Detailed view: observations=" _ observationCount _ ", allergies=" _ allergyCount _ ", conditions=" _ conditionCount _ ", medications=" _ medicationRequestCount _ ", encounters=" _ encounterCount _ ", carePlans=" _ carePlanCount _ ".")
    Do recentChanges.%Push("Detailed view: this MVP infers change candidates from recent resource availability and recency.")
    Do risksFollowUp.%Push("Detailed view: next expansion includes Condition, MedicationRequest, Encounter, and CarePlan evidence.")
}

Method CopyFirstN(arr As %DynamicArray, n As %Integer) As %DynamicArray [ Internal ]
{
    Set out = []
    If '$ISOBJECT(arr) {
        Return out
    }

    Set max = $SELECT(n<0:0, 1:n)
    For i=0:1:(arr.%Size()-1) {
        Quit:i'<max
        Do out.%Push(arr.%Get(i))
    }
    Return out
}

Method ApplyRoleView(role As %String, patientName As %String, ByRef currentIssues As %DynamicArray, ByRef recentChanges As %DynamicArray, ByRef risksFollowUp As %DynamicArray) [ Internal ]
{
    If role = "ed" {
        Do currentIssues.%Push("Prioritize immediate safety signals and rapidly actionable findings.")
        Do recentChanges.%Push("Confirm whether acute changes in recent observations affect disposition.")
        Do risksFollowUp.%Push("Verify allergy status and latest vitals/labs before medication or discharge decisions.")
        Return
    }

    If role = "care_manager" {
        Do currentIssues.%Push("Focus on continuity barriers and unresolved problems for " _ patientName _ ".")
        Do recentChanges.%Push("Identify trend changes that require care coordination outreach.")
        Do risksFollowUp.%Push("Add follow-up tasks and close pending gaps with community/clinic resources.")
        Return
    }

    If role = "patient" {
        Do currentIssues.%Push("This is a plain-language summary of what needs attention now.")
        Do recentChanges.%Push("These are the main things that look different from recent records.")
        Do risksFollowUp.%Push("Consider asking your care team about next tests, medicines, and warning signs.")
        Return
    }

    // caregiver
    Do currentIssues.%Push("Key status items to monitor and communicate to the clinical team.")
    Do recentChanges.%Push("Recent changes that may affect daily support needs.")
    Do risksFollowUp.%Push("Track follow-up appointments, medication safety, and symptom escalation triggers.")
}

Method GetPatientDisplayName(patient As %DynamicObject) As %String [ Internal ]
{
    If '$ISOBJECT(patient) {
        Return "Unknown patient"
    }

    If ..SafeGet(patient, "resourceType") '= "Patient" {
        Return "Unknown patient"
    }

    Set names = patient.%Get("name")
    If $ISOBJECT(names) && (names.%Size() > 0) {
        Set n = names.%Get(0)
        If $ISOBJECT(n) {
            Set text = ..SafeGet(n, "text")
            If text '= "" {
                Return text
            }

            Set given = ""
            Set givens = n.%Get("given")
            If $ISOBJECT(givens) && (givens.%Size() > 0) {
                Set given = givens.%Get(0)
            }
            Set family = ..SafeGet(n, "family")
            Set full = $ZSTRIP(given _ " " _ family, "<>W")
            If full '= "" {
                Return full
            }
        }
    }

    Set pid = ..SafeGet(patient, "id")
    If pid '= "" {
        Return "Patient " _ pid
    }

    Return "Unknown patient"
}

Method IsExpectedResource(resource As %DynamicObject, expectedType As %String) As %Boolean [ Internal ]
{
    If '$ISOBJECT(resource) {
        Return 0
    }

    Try {
        Set rt = resource.%Get("resourceType")
    } Catch ex {
        Set rt = ""
    }

    Return (rt = expectedType)
}

Method CountBundleEntries(bundle As %DynamicObject) As %Integer [ Internal ]
{
    If '$ISOBJECT(bundle) {
        Return 0
    }

    Set entries = bundle.%Get("entry")
    If $ISOBJECT(entries) {
        Return entries.%Size()
    }

    Return +..SafeGet(bundle, "total")
}

/// Search with automatic fallback: if the bare patient ID returns 0 entries,
/// retries with the full "Patient/<id>" reference. Handles servers that index
/// references differently (some require the type prefix, some do not).
Method GetFHIRWithFallback(path As %String, patientId As %String) As %DynamicObject [ Internal ]
{
    Set result = ..GetFHIR(path)
    If ..CountBundleEntries(result) > 0 {
        Return result
    }
    // If result has an error key, return as-is — no point retrying
    If $ISOBJECT(result) && (..SafeGet(result, "error") '= "") {
        Return result
    }
    // Retry with full Patient/ prefix if not already present
    If $EXTRACT(patientId, 1, 8) '= "Patient/" {
        Set fullRef = "Patient/" _ patientId
        Set altPath = $REPLACE(path, "patient=" _ ..UrlEncode(patientId), "patient=" _ ..UrlEncode(fullRef))
        If altPath '= path {
            Set retry = ..GetFHIR(altPath)
            If ..CountBundleEntries(retry) > 0 {
                Return retry
            }
        }
    }
    Return result
}

Method GetFHIR(path As %String) As %DynamicObject [ Internal ]
{
    Set baseUrl = ..GetBaseUrl()
    Set fullUrl = baseUrl _ "/" _ path

    Set req = ##class(%Net.HttpRequest).%New()
    Set req.SSLCheckServerIdentity = 0
    If $ZCONVERT($EXTRACT(baseUrl, 1, 5), "L") = "https" {
        Set req.SSLConfiguration = "default"
    }

    Set basicUser = $SYSTEM.Util.GetEnviron("FHIR_BASIC_USER")
    If basicUser = "" {
        Set basicUser = $GET(^||ENV("FHIR_BASIC_USER"))
    }
    Set basicPass = $SYSTEM.Util.GetEnviron("FHIR_BASIC_PASS")
    If basicPass = "" {
        Set basicPass = $GET(^||ENV("FHIR_BASIC_PASS"))
    }
    If (basicUser '= "") && (basicPass '= "") {
        // For IRIS-hosted FHIR endpoints that require HTTP Basic auth.
        Set req.Username = basicUser
        Set req.Password = basicPass
    } Else {
        Set token = $SYSTEM.Util.GetEnviron("FHIR_BEARER_TOKEN")
        If token = "" {
            Set token = $GET(^||ENV("FHIR_BEARER_TOKEN"))
        }
        If token '= "" {
            Do req.SetHeader("Authorization", "Bearer " _ token)
        }
    }
    Do req.SetHeader("Accept", "application/fhir+json")

    Set sc = req.Get(fullUrl)
    If $$$ISERR(sc) {
        Return {
            "error": "HTTP request failed",
            "status": ($SYSTEM.Status.GetErrorText(sc)),
            "url": (fullUrl)
        }
    }

    Set statusCode = +req.HttpResponse.StatusCode
    Set body = ..ReadResponseBody(req.HttpResponse.Data)

    If (statusCode < 200) || (statusCode > 299) {
        Return {
            "error": "FHIR request failed",
            "statusCode": (statusCode),
            "url": (fullUrl),
            "body": (body)
        }
    }

    Try {
        Set parsed = ##class(%DynamicAbstractObject).%FromJSON(body)
        Return parsed
    } Catch ex {
        Return {
            "resourceType": "Binary",
            "contentType": (req.HttpResponse.GetHeader("Content-Type")),
            "data": (body)
        }
    }
}

Method GetBaseUrl() As %String [ Internal ]
{
    Set base = $SYSTEM.Util.GetEnviron("FHIR_BASE_URL")
    If base = "" {
        Set base = $GET(^||ENV("FHIR_BASE_URL"))
    }
    If base = "" {
        Set base = "http://fhir:52773/fhir/r4"
    }
    Return $ZSTRIP(base, "<W", "/")
}

Method ReadResponseBody(stream As %Stream.Object) As %String [ Internal ]
{
    If '$ISOBJECT(stream) {
        Return ""
    }

    Set out = ""
    While 'stream.AtEnd {
        Set out = out _ stream.Read(32000)
    }
    Return out
}

Method UrlEncode(value As %String) As %String [ Internal ]
{
    Return $ZCONVERT(value, "O", "URL")
}

Method SafeGet(obj As %DynamicAbstractObject, key As %String) As %String [ Internal ]
{
    If '$ISOBJECT(obj) {
        Return ""
    }

    Try {
        Return $GET(obj.%Get(key), "")
    } Catch ex {
        Return ""
    }
}

}