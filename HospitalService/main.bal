import ballerina/http;
import ballerina/lang.value;

final http:Client pineValleyEp = check new ("http://localhost:9091/pineValley/");
final http:Client grandOakEp = check new ("http://localhost:9092/grandOak/");
final http:Client mapleRidgeEp = check new ("http://localhost:9093/mapleRidge/");

type PineValleyPayload record {
    string doctorType;
};

service / on new http:Listener(9090) {
    resource function get doctor/[string doctorType]() returns json|error? {

        @display {
            label: "node",
            templateId: "StartNode"
        }
        worker StartNode {
            _ = <- function;
            () -> switchDoctorType;
        }

        @display {
            label: "Check Doctor Type",
            templateId: "SwitchNode"
        }
        worker switchDoctorType {
            _ = <- StartNode;
            if doctorType == "ENT" {
                () -> callMapleRidge;
            } else {
                () -> buildPineValleyPayload;
                () -> callGrandOak;
            }
        }

        @display {
            label: "Call MapleRidge",
            templateId: "HttpRequestNode"
        }
        worker callMapleRidge returns error? {
            () _ = <- switchDoctorType;
            json res = check mapleRidgeEp->get("/doctor/" + doctorType);
            res -> respond;
        }

        @display {
            label: "Build Pine Valley Payload",
            templateId: "payloadNode"
        }
        worker buildPineValleyPayload {
            () _ = <- switchDoctorType;
            PineValleyPayload payload = {doctorType: doctorType};
            payload -> callPineValley;
        }

        @display {
            label: "Call PineValley",
            templateId: "HttpRequestNode"
        }
        worker callPineValley returns error? {
            PineValleyPayload payload = <- buildPineValleyPayload;
            json res = check pineValleyEp->post("/doctors/", payload);
            res -> mergeResults;
        }

        @display {
            label: "Call GrandOak",
            templateId: "HttpRequestNode"
        }
        worker callGrandOak returns error? {
            () _ = <- switchDoctorType;
            json res = check grandOakEp->get("/doctor/" + doctorType);
            res -> mergeResults;
        }

        @display {
            label: "Merge Results",
            templateId: "TransformNode"
        }
        worker mergeResults returns error? {
            json j1 = check <- callPineValley;
            json j2 = check <- callGrandOak;

            json res = check transformFunction(j1, j2);
            res -> respond;
        }

        @display {
            label: "Reply",
            templateId: "replyNode"
        }
        worker respond returns error? {
            json j = check <- mergeResults | callMapleRidge;
            j -> function;
        }

        () -> StartNode;
        json j = check <- respond;
        return j;
    }
}

function transformFunction(json j1, json j2) returns json|error => check value:mergeJson(j1, j2);
