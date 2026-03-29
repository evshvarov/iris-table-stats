Class esh.iris.entity.api.spec Extends %REST.Spec
{

Parameter HandleCorsRequest = 1;

Parameter CONTENTTYPE = "application/json";

Parameter ExposeServerExceptions = 1;

XData OpenAPI [ MimeType = application/json ]
{
{
  "swagger": "2.0",
  "info": {
    "title": "IRIS Entity API",
    "version": "1.0.0",
    "description": "Inspect persistent classes in the current namespace and fetch their data."
  },
  "basePath": "/iris-table-stats/api",
  "consumes": [
    "application/json"
  ],
  "produces": [
    "application/json"
  ],
  "paths": {
    "/_spec": {
      "get": {
        "summary": "Get OpenAPI spec",
        "operationId": "GetSpec",
        "responses": {
          "200": {
            "description": "Swagger spec JSON",
            "schema": { "type": "object" }
          }
        }
      }
    },
    "/classes": {
      "get": {
        "summary": "List persistent classes in the current namespace",
        "operationId": "ListPersistentClasses",
        "parameters": [
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "type": "integer",
            "format": "int32",
            "default": 100
          },
          {
            "name": "offset",
            "in": "query",
            "required": false,
            "type": "integer",
            "format": "int32",
            "default": 0
          },
          {
            "name": "package",
            "in": "query",
            "required": false,
            "type": "string"
          }
        ],
        "responses": {
          "200": {
            "description": "Persistent classes",
            "schema": {
              "$ref": "#/definitions/PersistentClassListResponse"
            }
          },
          "500": {
            "description": "Server error"
          }
        }
      }
    },
    "/classes/{className}/data": {
      "get": {
        "summary": "Get data from a persistent class",
        "operationId": "GetPersistentClassData",
        "parameters": [
          {
            "name": "className",
            "in": "path",
            "required": true,
            "type": "string"
          },
          {
            "name": "limit",
            "in": "query",
            "required": false,
            "type": "integer",
            "format": "int32",
            "default": 100
          },
          {
            "name": "offset",
            "in": "query",
            "required": false,
            "type": "integer",
            "format": "int32",
            "default": 0
          }
        ],
        "responses": {
          "200": {
            "description": "Class data",
            "schema": {
              "$ref": "#/definitions/PersistentClassDataResponse"
            }
          },
          "400": {
            "description": "Invalid request"
          },
          "404": {
            "description": "Class not found"
          },
          "500": {
            "description": "Server error"
          }
        }
      }
    }
  },
  "definitions": {
    "PersistentClassInfo": {
      "type": "object",
      "properties": {
        "name": {
          "type": "string"
        },
        "description": {
          "type": "string"
        },
        "sqlSchemaName": {
          "type": "string"
        },
        "sqlTableName": {
          "type": "string"
        }
      }
    },
    "PersistentClassListResponse": {
      "type": "object",
      "properties": {
        "namespace": {
          "type": "string"
        },
        "items": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/PersistentClassInfo"
          }
        },
        "count": {
          "type": "integer",
          "format": "int32"
        },
        "limit": {
          "type": "integer",
          "format": "int32"
        },
        "offset": {
          "type": "integer",
          "format": "int32"
        }
      }
    },
    "PersistentClassDataResponse": {
      "type": "object",
      "properties": {
        "namespace": {
          "type": "string"
        },
        "className": {
          "type": "string"
        },
        "items": {
          "type": "array",
          "items": {
            "type": "object"
          }
        },
        "count": {
          "type": "integer",
          "format": "int32"
        },
        "limit": {
          "type": "integer",
          "format": "int32"
        },
        "offset": {
          "type": "integer",
          "format": "int32"
        }
      }
    }
  }
}
}

}
