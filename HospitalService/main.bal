import ballerina/http;
import ballerina/lang.value;

final http:Client pineValleyEp = check new ("http://localhost:9091/pineValley/");
final http:Client grandOakEp = check new ("http://localhost:9092/grandOak/");

type PineValleyPayload record {
    string doctorType;
};

service / on new http:Listener(9090) {
    resource function get doctor/[string doctorType]() returns json|error? {

        @display {
            label: "Check Doctor Type",
            templateId: "SwitchNode"
        }
        worker switchDoctorType {
            if doctorType == "ENT" {
                () -> callGrandOak;
            } else {
                () -> callGrandOak;
                () -> buildPineValleyPayload;
            }
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
            label: "Call Grand Oak",
            templateId: "HttpRequestNode"
        }
        worker callPineValley returns error? {
            PineValleyPayload payload = <- buildPineValleyPayload;
            json res = check pineValleyEp->post("/doctors/", payload);
            res -> mergeResults;
        }

        @display {
            label: "Call Grand Oak",
            templateId: "HttpRequestNode"
        }
        worker callGrandOak returns error? {
            () _ = <- switchDoctorType | switchDoctorType;
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
            templateId: "HttpResponseNode"
        }
        worker respond returns error? {
            json j = check <- mergeResults;
            j -> function;
        }

        json j = check <- respond;
        return j;
    }
}

function transformFunction(json j1, json j2) returns json|error => check value:mergeJson(j1, j2);
