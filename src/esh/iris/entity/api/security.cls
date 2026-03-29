Class esh.iris.entity.api.security Extends %RegisteredObject
{

Parameter webapp = "/iris-table-stats/api";

ClassMethod SetupSecurity() As %Status
{
    Set tSC = $$$OK
    Set sc = ..IntroduceSQLARole()
    If $$$ISERR(sc) {
        Set tSC = sc
    }
    Set sc = ..AddARole()
    If $$$ISERR(sc) {
        Set tSC = sc
    }
    Set sc = ..AddCORS()
    If $$$ISERR(sc) {
        Set tSC = sc
    }
    Set sc = ..IntroduceARoleDBUSER()
    If $$$ISERR(sc) {
        Set tSC = sc
    }
    Set sc = ..AddARoleToUser()
    If $$$ISERR(sc) {
        Set tSC = sc
    }
    Quit tSC
}

ClassMethod IntroduceSQLARole() As %Status
{
    &SQL(CREATE ROLE irisentityapi)
    If (SQLCODE '= 0) && (SQLCODE '= -100) {
        Quit $$$ERROR($$$GeneralError, "Error creating role: "_SQLCODE)
    }
    Quit $$$OK
}

ClassMethod IntroduceARoleDBUSER() As %Status
{
    &SQL(CREATE ROLE DB_USER_Read)
    If (SQLCODE '= 0) && (SQLCODE '= -100) {
        Quit $$$ERROR($$$GeneralError, "Error creating role: "_SQLCODE)
    }

    New $NAMESPACE
    Set $NAMESPACE="%SYS"
    Set properties("Resources")="%DB_USER:R"

    Set sc = ##class(Security.Roles).Modify("DB_USER_Read", .properties)
    If $$$ISERR(sc) {
        Quit $$$ERROR($$$GeneralError, "Error modifying role: "_sc)
    }
    Quit sc
}

ClassMethod AddARoleToUser(user = "CSPSystem", ARole = "DB_USER_Read") As %Status
{
    New $NAMESPACE
    Set $NAMESPACE="%SYS"

    Set status = ##class(Security.Users).Get(user, .userProps)
    If $$$ISERR(status) {
        Quit status
    }
    If (("," _ $Get(userProps("Roles")) _ ",") '[ ("," _ ARole _ ",")) {
        Set $Piece(userProps("Roles"), ",", *) = ARole
    }
    Set status = ##class(Security.Users).Modify(user, .userProps)
    Quit status
}

ClassMethod AddARole(appname = "", appARole = "irisentityapi") As %Status
{
    New $NAMESPACE
    Set $NAMESPACE="%SYS"

    If appname = "" {
        Set appname = ..#webapp
    }
    Set status = ##class(Security.Applications).Get(appname, .appProps)
    If $$$ISERR(status) {
        Quit status
    }
    If (":" _ $Get(appProps("MatchRoles")) _ ":") '[ (":" _ appARole _ ":") {
        Set appProps("MatchRoles") = $Get(appProps("MatchRoles")) _ ":" _ appARole
    }
    Set status = ##class(Security.Applications).Modify(appname, .appProps)
    Quit status
}

ClassMethod AddCORS(appname = "") As %Status
{
    New $NAMESPACE
    Set $NAMESPACE="%SYS"

    If appname = "" {
        Set appname = ..#webapp
    }
    Set status = ##class(Security.Applications).Get(appname, .appProps)
    If $$$ISERR(status) {
        Quit status
    }
    Set appProps("CorsAllowlist") = "*"
    Set appProps("CorsCredentialsAllowed") = 1
    Set appProps("CorsHeadersList") = "Content-Type,Authorization,Accept-Language,X-Requested-With,session"
    Set status = ##class(Security.Applications).Modify(appname, .appProps)
    Quit status
}

}
