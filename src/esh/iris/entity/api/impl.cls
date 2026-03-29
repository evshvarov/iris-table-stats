Class esh.iris.entity.api.impl Extends %REST.Impl [ ProcedureBlock ]
{

Parameter ExposeServerExceptions = 1;

/// /_spec
/// Get OpenAPI spec
ClassMethod GetSpec() As %DynamicObject
{
    set specname=$p(..%ClassName(1),".impl")
    Set spec = {}.%FromJSON(##class(%Dictionary.CompiledXData).%OpenId(specname_".spec||OpenAPI").Data)
    Set url = $Select(%request.Secure:"https",1:"http") _ "://" _ $Get(%request.CgiEnvs("SERVER_NAME")) _ ":" _ $Get(%request.CgiEnvs("SERVER_PORT")) _ %request.Application
    Set spec.servers = [{"url" : (url)}]
    Quit spec
}

ClassMethod ListPersistentClasses(limit As %Integer = 100, offset As %Integer = 0, package As %String = "") As %DynamicObject
{
    Set limit = ..NormalizeLimit(limit)
    Set offset = ..NormalizeOffset(offset)
    Set result = ..NewPagedResult(limit, offset)
    Set stmt = ##class(%SQL.Statement).%New()
    Set sql = "SELECT Name, Description, SqlSchemaName, SqlTableName FROM %Dictionary.CompiledClass WHERE ClassType = ?"
    If package '= "" {
        Set sql = sql _ " AND Name %STARTSWITH ?"
    }
    Set sql = sql _ " ORDER BY Name LIMIT ? OFFSET ?"
    Set sc = stmt.%Prepare(sql)
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit result
    }

    If package '= "" {
        Set rset = stmt.%Execute("persistent", package, limit, offset)
    } Else {
        Set rset = stmt.%Execute("persistent", limit, offset)
    }
    If rset.%SQLCODE < 0 {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "SQL error: "_rset.%Message)
        Quit result
    }

    While rset.%Next() {
        Set item = {}
        Set item.name = rset.%Get("Name")
        Set item.description = rset.%Get("Description")
        Set item.sqlSchemaName = rset.%Get("SqlSchemaName")
        Set item.sqlTableName = rset.%Get("SqlTableName")
        Do result.items.%Push(item)
    }

    Do result.%Set("count", result.items.%Size())
    Quit result
}

ClassMethod GetPersistentClassData(className As %String, limit As %Integer = 100, offset As %Integer = 0) As %DynamicObject
{
    Set limit = ..NormalizeLimit(limit)
    Set offset = ..NormalizeOffset(offset)
    Set result = ..NewPagedResult(limit, offset)
    Do result.%Set("className", className)
    If ('..IsValidClassName(className)) {
        Do ..%SetStatusCode(400)
        Do ..%SetHeader("X-Error", "Invalid className")
        Quit result
    }

    Set classInfo = ..GetPersistentClassInfo(className)
    If '$IsObject(classInfo) {
        Do ..%SetStatusCode(404)
        Do ..%SetHeader("X-Error", "Persistent class not found: "_className)
        Quit result
    }

    Set tableRef = ..GetSqlTableReference(classInfo)
    If tableRef = "" {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Unable to resolve SQL table for class: "_className)
        Quit result
    }

    Set propInfos = ..GetClassPropertyInfos(className)
    If '$IsObject(propInfos) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Unable to resolve properties for class: "_className)
        Quit result
    }

    Set sql = "SELECT %ID AS ObjectId"
    Set index = -1
    While (index + 1) < propInfos.%Size() {
        Set index = index + 1
        Set propInfo = propInfos.%Get(index)
        Set sql = sql _ ", " _ ..QuoteIdentifier(propInfo.name)
    }
    Set sql = sql _ " FROM "_tableRef_" ORDER BY %ID LIMIT ? OFFSET ?"

    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare(sql)
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit result
    }

    Set rset = stmt.%Execute(limit, offset)
    If rset.%SQLCODE < 0 {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "SQL error: "_rset.%Message)
        Quit result
    }

    While rset.%Next() {
        Set item = {}
        Do item.%Set("%Id", rset.%Get("ObjectId"))
        Do ..PopulateRowData(.item, rset, propInfos)
        Do result.items.%Push(item)
    }

    Do result.%Set("count", result.items.%Size())
    Quit result
}

ClassMethod NewPagedResult(limit As %Integer, offset As %Integer) As %DynamicObject [ Private ]
{
    Set result = {}
    Do result.%Set("namespace", $Namespace)
    Do result.%Set("items", [])
    Do result.%Set("count", 0)
    Do result.%Set("limit", ..NormalizeLimit(limit))
    Do result.%Set("offset", ..NormalizeOffset(offset))
    Quit result
}

ClassMethod NormalizeLimit(limit As %Integer) As %Integer [ Private ]
{
    Quit $Select(limit>0:limit, 1:100)
}

ClassMethod NormalizeOffset(offset As %Integer) As %Integer [ Private ]
{
    Quit $Select(offset'<0:offset, 1:0)
}

ClassMethod IsValidClassName(className As %String) As %Boolean [ Private ]
{
    Set length = $Length(className)
    If length = 0 {
        Quit 0
    }

    Set valid = 1
    For index = 1:1:length {
        Set ch = $Extract(className, index)
        Continue:((ch?1A) || (ch?1N) || (ch = ".") || (ch = "%"))
        Set valid = 0
        Quit
    }

    Quit valid
}

ClassMethod GetPersistentClassInfo(className As %String) As %DynamicObject [ Private ]
{
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare("SELECT Name, SqlSchemaName, SqlTableName FROM %Dictionary.CompiledClass WHERE Name = ? AND ClassType = ?")
    If $$$ISERR(sc) {
        Quit ""
    }

    Set rset = stmt.%Execute(className, "persistent")
    If rset.%SQLCODE < 0 {
        Quit ""
    }
    If 'rset.%Next() {
        Quit ""
    }

    Set item = {}
    Set item.Name = rset.%Get("Name")
    Set item.SqlSchemaName = rset.%Get("SqlSchemaName")
    Set item.SqlTableName = rset.%Get("SqlTableName")
    Quit item
}

ClassMethod GetSqlTableReference(classInfo As %DynamicObject) As %String [ Private ]
{
    Set schemaName = classInfo.SqlSchemaName
    Set tableName = classInfo.SqlTableName

    If (schemaName = "") || (tableName = "") {
        Set className = classInfo.Name
        Set lastPiece = $Length(className, ".")
        Set schemaName = $Piece(className, ".", 1, lastPiece - 1)
        Set tableName = $Piece(className, ".", lastPiece)
    }

    If schemaName = "" {
        Quit ..QuoteIdentifier(tableName)
    }
    Quit ..QuoteIdentifier(schemaName) _ "." _ ..QuoteIdentifier(tableName)
}

ClassMethod QuoteIdentifier(name As %String) As %String [ Private ]
{
    Quit """" _ $Replace(name, """", """""") _ """"
}

ClassMethod GetClassPropertyInfos(className As %String) As %DynamicArray [ Private ]
{
    Set stmt = ##class(%SQL.Statement).%New()
    Set sql = "SELECT Name, Type FROM %Dictionary.CompiledProperty WHERE parent = ? AND Transient = 0 AND Calculated = 0 AND MultiDimensional = 0 ORDER BY Name"
    Set sc = stmt.%Prepare(sql)
    If $$$ISERR(sc) {
        Quit ""
    }

    Set rset = stmt.%Execute(className)
    If rset.%SQLCODE < 0 {
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

ClassMethod PopulateRowData(ByRef item As %DynamicObject, rset As %SQL.StatementResult, propInfos As %DynamicArray) [ Private ]
{
    Set index = -1
    While (index + 1) < propInfos.%Size() {
        Set index = index + 1
        Set propInfo = propInfos.%Get(index)
        Set propName = propInfo.name
        Set value = rset.%Get(propName)
        Do item.%Set(propName, ..NormalizeValue(value, propInfo.type))
    }
}

ClassMethod NormalizeValue(value, type As %String = "") [ Private ]
{
    If $Extract(type, 1) = "%" {
        Quit value
    }

    If value = "" {
        Quit value
    }

    Set ref = {}
    Do ref.%Set("className", type)
    Do ref.%Set("id", value)
    Quit ref
}

}
