Class esh.iris.entity.tests.UnitTests Extends %UnitTest.TestCase
{

Method InitRequestResponse() [ Private ]
{
    Set %response = ##class(%CSP.Response).%New()
    Set %request = ##class(%CSP.Request).%New()
    Set %request.CgiEnvs("SERVER_NAME") = "localhost"
    Set %request.CgiEnvs("SERVER_PORT") = "52773"
}

Method CreateSampleData(ByRef parentId As %String, ByRef childId As %String) [ Private ]
{
    Set parent = ##class(esh.iris.entity.tests.SampleParent).%New()
    Set parent.Name = "Parent "_$J_"-"_$Random(10000)
    Set sc = parent.%Save()
    Do $$$AssertStatusOK(sc, "Saving sample parent failed")

    Set child = ##class(esh.iris.entity.tests.SampleChild).%New()
    Set child.Name = "Child "_$J_"-"_$Random(10000)
    Set child.Amount = 42
    Set child.Parent = parent
    Set sc = child.%Save()
    Do $$$AssertStatusOK(sc, "Saving sample child failed")

    Set parentId = parent.%Id()
    Set childId = child.%Id()
}

Method CleanupSampleData(parentId As %String, childId As %String) [ Private ]
{
    If childId '= "" {
        Do ##class(esh.iris.entity.tests.SampleChild).%DeleteId(childId)
    }
    If parentId '= "" {
        Do ##class(esh.iris.entity.tests.SampleParent).%DeleteId(parentId)
    }
}

Method FindClassByName(items As %DynamicArray, target As %String) As %DynamicObject [ Private ]
{
    For i = 0:1:items.%Size()-1 {
        Set item = items.%Get(i)
        If $IsObject(item) {
            If item.name = target {
                Quit item
            }
        }
    }
    Quit ""
}

Method FindRowById(items As %DynamicArray, targetId As %String) As %DynamicObject [ Private ]
{
    For i = 0:1:items.%Size()-1 {
        Set item = items.%Get(i)
        If $IsObject(item) {
            If item.%Get("%Id") = targetId {
                Quit item
            }
        }
    }
    Quit ""
}

Method TestGetSpec()
{
    Do ..InitRequestResponse()
    Set spec = ##class(esh.iris.entity.api.impl).GetSpec()
    Do $$$AssertTrue($IsObject(spec), "Spec response must be an object")
    Do $$$AssertEquals(spec.swagger, "2.0", "Unexpected swagger version")
    Do $$$AssertTrue(spec.paths.%IsDefined("/classes"), "Spec must expose /classes")
    Do $$$AssertTrue(spec.paths.%IsDefined("/classes/{className}/data"), "Spec must expose class data endpoint")
}

Method TestListPersistentClasses()
{
    Do ..InitRequestResponse()
    Set result = ##class(esh.iris.entity.api.impl).ListPersistentClasses(200, 0, "esh.iris.entity.tests.")
    Do $$$AssertTrue($IsObject(result), "List response must be an object")
    Do $$$AssertEquals(result.namespace, $Namespace, "Namespace mismatch")
    Do $$$AssertEquals(result.limit, 200, "Limit mismatch")
    Do $$$AssertEquals(result.offset, 0, "Offset mismatch")
    Do $$$AssertTrue($IsObject(result.items), "Items must be a dynamic array")

    Set classInfo = ..FindClassByName(result.items, "esh.iris.entity.tests.SampleChild")
    Do $$$AssertTrue($IsObject(classInfo), "SampleChild should be listed as persistent")
    Do $$$AssertEquals(classInfo.sqlTableName, "SampleChild", "Unexpected SQL table name")
}

Method TestGetPersistentClassData()
{
    Do ..InitRequestResponse()
    Set parentId = "", childId = ""
    Try {
        Do ..CreateSampleData(.parentId, .childId)
        Set result = ##class(esh.iris.entity.api.impl).GetPersistentClassData("esh.iris.entity.tests.SampleChild", 50, 0)
        Do $$$AssertTrue($IsObject(result), "Data response must be an object")
        Do $$$AssertEquals(result.className, "esh.iris.entity.tests.SampleChild", "Class name mismatch")
        Do $$$AssertEquals(result.limit, 50, "Limit mismatch")
        Do $$$AssertTrue($IsObject(result.items), "Items must be a dynamic array")

        Set row = ..FindRowById(result.items, childId)
        Do $$$AssertTrue($IsObject(row), "Inserted SampleChild row not found")
        Do $$$AssertEquals(row.Name, ##class(esh.iris.entity.tests.SampleChild).%OpenId(childId).Name, "Name mismatch")
        Do $$$AssertEquals(row.Amount, 42, "Amount mismatch")
        Do $$$AssertTrue($IsObject(row.Parent), "Parent reference should be serialized as object")
        Do $$$AssertEquals(row.Parent.className, "esh.iris.entity.tests.SampleParent", "Parent class mismatch")
        Do $$$AssertEquals(row.Parent.id, parentId, "Parent id mismatch")
    } Catch ex {
        Do ..CleanupSampleData(parentId, childId)
        Throw ex
    }
    Do ..CleanupSampleData(parentId, childId)
}

Method TestGetPersistentClassDataInvalidClass()
{
    Do ..InitRequestResponse()
    Set result = ##class(esh.iris.entity.api.impl).GetPersistentClassData("bad class name", 10, 0)
    Do $$$AssertTrue($IsObject(result), "Invalid class response must be an object")
    Do $$$AssertEquals(%response.Status, 400, "Invalid class should set 400")
}

Method TestGetPersistentClassDataMissingClass()
{
    Do ..InitRequestResponse()
    Set result = ##class(esh.iris.entity.api.impl).GetPersistentClassData("esh.iris.entity.tests.DoesNotExist", 10, 0)
    Do $$$AssertTrue($IsObject(result), "Missing class response must be an object")
    Do $$$AssertEquals(%response.Status, 404, "Missing class should set 404")
}

}
