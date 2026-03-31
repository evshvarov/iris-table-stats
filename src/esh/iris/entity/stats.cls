Class esh.iris.entity.stats Extends %RegisteredObject
{

ClassMethod CalculatePopulationStats(className As %String, ByRef sc As %Status) As %DynamicObject
{
    Set sc = $$$OK
    Set result = {}
    Do result.%Set("namespace", $Namespace)
    Do result.%Set("className", className)
    Do result.%Set("totalRows", 0)
    Do result.%Set("columns", [])

    Set propInfos = ..GetClassPropertyInfos(className, .sc)
    If $$$ISERR(sc) {
        Quit result
    }

    Set columns = result.columns
    Set index = -1
    While (index + 1) < propInfos.%Size() {
        Set index = index + 1
        Set propInfo = propInfos.%Get(index)
        Set columnStat = {}
        Do columnStat.%Set("name", propInfo.name)
        Do columnStat.%Set("type", propInfo.type)
        Do columnStat.%Set("populatedCount", 0)
        Do columnStat.%Set("emptyCount", 0)
        Do columnStat.%Set("populatedPercent", 0)
        Do columnStat.%Set("emptyPercent", 0)
        Do columns.%Push(columnStat)
    }

    Set extent = ##class(%ResultSet).%New(className_":Extent")
    Set sc = extent.Execute()
    If $$$ISERR(sc) {
        Quit result
    }

    Set totalRows = 0
    While extent.Next() {
        Set objectId = extent.Data("ID")
        Set obj = $classmethod(className, "%OpenId", objectId)
        Continue:'$IsObject(obj)
        Set totalRows = totalRows + 1
        Do ..UpdateColumnStats(columns, obj, propInfos)
    }

    Do result.%Set("totalRows", totalRows)
    Do ..FinalizeColumnStats(columns, totalRows)
    Quit result
}

ClassMethod GetClassPropertyInfos(className As %String, ByRef sc As %Status) As %DynamicArray [ Private ]
{
    Set stmt = ##class(%SQL.Statement).%New()
    Set sql = "SELECT Name, Type FROM %Dictionary.CompiledProperty WHERE parent = ? AND Private = 0 AND Transient = 0 AND Calculated = 0 AND MultiDimensional = 0 ORDER BY Name"
    Set sc = stmt.%Prepare(sql)
    If $$$ISERR(sc) {
        Quit ""
    }

    Set rset = stmt.%Execute(className)
    If rset.%SQLCODE < 0 {
        Set sc = $$$ERROR($$$GeneralError, "SQL error: "_rset.%Message)
        Quit ""
    }

    Set propInfos = []
    While rset.%Next() {
        Set propInfo = {}
        Set propInfo.name = rset.%Get("Name")
        Set propInfo.type = rset.%Get("Type")
        Do propInfos.%Push(propInfo)
    }
    Quit propInfos
}

ClassMethod UpdateColumnStats(columns As %DynamicArray, obj As %RegisteredObject, propInfos As %DynamicArray) [ Private ]
{
    Set index = -1
    While (index + 1) < propInfos.%Size() {
        Set index = index + 1
        Set propInfo = propInfos.%Get(index)
        Set columnStat = columns.%Get(index)
        Try {
            Set value = $PROPERTY(obj, propInfo.name)
        } Catch ex {
            Set value = ""
        }
        If ..IsEmptyValue(value) {
            Do columnStat.%Set("emptyCount", columnStat.emptyCount + 1)
        } Else {
            Do columnStat.%Set("populatedCount", columnStat.populatedCount + 1)
        }
    }
}

ClassMethod FinalizeColumnStats(columns As %DynamicArray, totalRows As %Integer) [ Private ]
{
    Set index = -1
    While (index + 1) < columns.%Size() {
        Set index = index + 1
        Set columnStat = columns.%Get(index)
        Do columnStat.%Set("populatedPercent", ..Percent(columnStat.populatedCount, totalRows))
        Do columnStat.%Set("emptyPercent", ..Percent(columnStat.emptyCount, totalRows))
    }
}

ClassMethod IsEmptyValue(value) As %Boolean [ Private ]
{
    If $IsObject(value) {
        Quit 0
    }
    Quit $Select($Length(value)=0:1, 1:0)
}

ClassMethod Percent(value As %Integer, total As %Integer) As %Double [ Private ]
{
    If total=0 {
        Quit 0
    }
    Quit $Justify((value*100.0)/total,0,2)
}

}
