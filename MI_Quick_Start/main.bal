import ballerina/http;
import ballerina/lang.value;
import ballerina/log;

final http:Client pineValleyEp = check new ("http://localhost:9091/pineValley/");
final http:Client grandOakEp = check new ("http://localhost:9092/grandOak/");

type PineValleyPayload record {
    string doctorType;
};

service / on new http:Listener(9090) {

    // Simplest Case : All are code blocks
    resource function get case1/doctor/[string doctorType]() returns json|error? {
        // Cloned paths
        worker callGrandOak returns error? {
            json res = check grandOakEp->get("/doctors/" + doctorType);
            res -> merge;
        }
        worker callPineValley returns error? {
            PineValleyPayload payload = {doctorType: doctorType};
            json res = check pineValleyEp->post("/doctors/", payload);
            res -> merge;
        }

        worker merge returns error? {
            json res1 = check <- callGrandOak;
            json res2 = check <- callPineValley;
            // Code Block or Aggregated Node
            json mergedRes = check value:mergeJson(res1, res2);
            mergedRes -> function;
        }

        json res = check <- merge;
        return res;
    }

    // Case 2 - With Multi Workers, with Nodes
    resource function get case2/doctor/[string doctorType]() returns json|error? {

        // Cloned paths
        worker callGrandOak returns error? {
            json res = check grandOakEp->get("/doctors/" + doctorType);
            res -> merge;
        }
        worker buildPineValleyPayload returns () {
            PineValleyPayload payload = {doctorType: doctorType};
            payload -> callPineValley;
        }
        worker callPineValley returns error? {
            PineValleyPayload payload = <- buildPineValleyPayload;
            json res = check pineValleyEp->post("/doctors/", payload);
            res -> merge;
        }
        worker merge returns error? {
            json res1 = check <- callGrandOak;
            json res2 = check <- callPineValley;
            // Code Block or Aggregated Node
            json mergedRes = check value:mergeJson(res1, res2);
            mergedRes -> function;
        }

        json res = check <- merge;
        return res;
    }

    // Case 3 - Case 2, but with Start Flow
    resource function get case3/doctor/[string doctorType]() returns json|error? {

        // Cloned paths
        worker callGrandOak returns error? {
            _ = <- function;
            json res = check grandOakEp->get("/doctors/" + doctorType);
            res -> merge;
        }
        worker buildPineValleyPayload returns () {
            _ = <- function;
            PineValleyPayload payload = {doctorType: doctorType};
            payload -> callPineValley;
        }
        worker callPineValley returns error? {
            PineValleyPayload payload = <- buildPineValleyPayload;
            json res = check pineValleyEp->post("/doctors/", payload);
            res -> merge;
        }
        worker merge returns error? {
            json res1 = check <- callGrandOak;
            json res2 = check <- callPineValley;
            // Code Block or Aggregated Node
            json mergedRes = check value:mergeJson(res1, res2);
            mergedRes -> function;
        }

        () -> callGrandOak;
        () -> buildPineValleyPayload;
        json res = check <- merge;
        return res;
    }

    // Case 4 - Case 2 with error handlers
    resource function get case4/doctor/[string doctorType]() returns json|error? {

        // Cloned paths
        worker callGrandOak {
            _ = <- function;
            json res = check grandOakEp->get("/doctors/" + doctorType);
            res -> merge;
        } on fail var e {
            e -> errorHandler;
        }

        worker buildPineValleyPayload {
            _ = <- function;
            PineValleyPayload payload = {doctorType: doctorType};
            payload -> callPineValley;
        } on fail var e {
            e -> errorHandler;
        }

        worker callPineValley {
            PineValleyPayload payload = <- buildPineValleyPayload;
            json res = check pineValleyEp->post("/doctors/", payload);
            res -> merge;
        } on fail var e {
            e -> errorHandler;
        }

        worker merge {
            json res1 = check <- callGrandOak;
            json res2 = check <- callPineValley;
            // Code Block or Aggregated Node
            json mergedRes = check value:mergeJson(res1, res2);
            mergedRes -> function;
        } on fail var e {
            e -> errorHandler;
        }

        worker errorHandler {
            error e = <- callGrandOak | buildPineValleyPayload | callPineValley | merge;
            e -> function;
        }

        () -> callGrandOak;
        () -> buildPineValleyPayload;
        json res = check <- merge | errorHandler;
        return res;
    }

    // Case 5 - Case 2 with error handlers, with Caller
    resource function get case5/doctor/[string doctorType](http:Caller caller) returns error? {

        // Cloned paths
        worker callGrandOak {
            _ = <- function;
            json res = check grandOakEp->get("/doctors/" + doctorType);
            res -> merge;
        } on fail var e {
            e -> errorHandler;
        }

        worker buildPineValleyPayload {
            _ = <- function;
            PineValleyPayload payload = {doctorType: doctorType};
            payload -> callPineValley;
        } on fail var e {
            e -> errorHandler;
        }

        worker callPineValley {
            PineValleyPayload payload = <- buildPineValleyPayload;
            json res = check pineValleyEp->post("/doctors/", payload);
            res -> merge;
        } on fail var e {
            e -> errorHandler;
        }

        worker merge {
            json res1 = check <- callGrandOak;
            json res2 = check <- callPineValley;
            // Code Block or Aggregated Node
            json mergedRes = check value:mergeJson(res1, res2);
            mergedRes -> respond;
        } on fail var e {
            e -> errorHandler;
        }

        worker respond {
            json j = <- merge;
            _ = check caller->respond(j);
        } on fail var e {
            e -> errorHandler;
        }

        worker errorHandler {
            error e = <- callGrandOak | buildPineValleyPayload | callPineValley | merge | respond;
            e -> logError;
            () -> createError;
        }

        worker logError {
            error e = <- errorHandler;
            log:printError("Error occurred", e);
        }

        worker createError {
            _ = <- errorHandler;
            json j = {message: "Error occurred"};
            j -> respondError;
        }

        worker respondError {
            json j = <- createError;
            _ = check caller->respond(j);
        } on fail {
            // Ignore
        }

        () -> callGrandOak;
        () -> buildPineValleyPayload;
    }

    // Case 6 - Case 5 with error handlers, but without http Caller. 
    resource function get case6/doctor/[string doctorType]() returns json|error? {

        // Cloned paths
        worker callGrandOak {
            _ = <- function;
            json res = check grandOakEp->get("/doctors/" + doctorType);
            res -> merge;
        } on fail var e {
            e -> errorHandler;
        }

        worker buildPineValleyPayload {
            _ = <- function;
            PineValleyPayload payload = {doctorType: doctorType};
            payload -> callPineValley;
        } on fail var e {
            e -> errorHandler;
        }

        worker callPineValley {
            PineValleyPayload payload = <- buildPineValleyPayload;
            json res = check pineValleyEp->post("/doctors/", payload);
            res -> merge;
        } on fail var e {
            e -> errorHandler;
        }

        worker merge {
            json res1 = check <- callGrandOak;
            json res2 = check <- callPineValley;
            // Code Block or Aggregated Node
            json mergedRes = check value:mergeJson(res1, res2);
            mergedRes -> function;
        } on fail var e {
            e -> errorHandler;
        }

        worker errorHandler {
            error e = <- callGrandOak | buildPineValleyPayload | callPineValley | merge | respond;
            e -> logError;
            () -> createError;
        }

        worker logError {
            error e = <- errorHandler;
            log:printError("Error occurred", e);
            () -> function;
        }

        worker createError {
            _ = <- errorHandler;
            json j = {message: "Error occurred"};
            j -> function;
        }

        () -> callGrandOak;
        () -> buildPineValleyPayload;
        json j = check <- merge | createError;
        return j;
    }
}
