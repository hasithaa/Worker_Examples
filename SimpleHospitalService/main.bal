import ballerina/http;
import ballerina/io;

final http:Client pineValleyEp = check new ("http://localhost:9091/pineValley/");
final http:Client grandOakEp = check new ("http://localhost:9092/grandOak/");
final http:Client mapleRidgeEp = check new ("http://localhost:9093/mapleRidge/");
final http:Client insurance = check new ("http://localhost:9093/insurance/");

// Transformations are functions. 

type DoctorType record {|
    string name;
    string doctorType;
|};

type PineValleyReq record {|
    string doctorType;
|};

type Result DoctorType[];

service / on new http:Listener(9090) {

    resource function get doctor/[string doctorType]() returns json|error {

        if doctorType == "ENT" {
            // Call Maple Ridge
            Result res = check mapleRidgeEp->get("/doctor/" + doctorType);
            return res;
        } else {
            // Call Pine Valley & Grand Oak
            fork {
                worker pineValley returns Result|error {
                    Result res = check pineValleyEp->get("/doctor/" + doctorType);
                    return res;
                }
                worker grandOak returns Result|error {
                    PineValleyReq req = {doctorType: doctorType};
                    Result res = check grandOakEp->post("/doctor/", req);
                    return res;
                }
            }
            Result result = [];
            record {Result|error pineValley; Result|error grandOak;} aggregate = wait {pineValley, grandOak};

            Result pineValleyRes = check aggregate.pineValley;
            Result grandOakRes = check aggregate.grandOak;
            result.push(...pineValleyRes);
            result.push(...grandOakRes);
            return result;
        }
    }

resource function post doctorTypes/[string doctorType]() returns json|error {
    Result res = check mapleRidgeEp->get("/doctor/" + doctorType);
    foreach var doctor in res {
        json j = check insurance->post("/doctor/", {"doctor": doctor.doctorType});
        if j.status != "error" {
            return {"status": "error"};
        }
        if j.status == "Unknown" {
            continue;
        } else if j.status == "New" {
            break;
        }
        io:println("Data Submit");
    }
    return {"status": "success"};
}
}

const node2 = ""; // metadata
const node3 = ""; // metadata
