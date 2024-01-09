import ballerina/http;
import ballerina/io;

final http:Client exampleCom = check new ("http://example.com"); // Step 1
final http:Client exampleNet = check new ("http://example.net"); // Step 2

service / on new http:Listener(9090) {

    // Option 1 - using value match and with header binding.
    resource function get route1(@http:Header {name: "X-url"} string path, http:Request req) returns http:NotFound & readonly|error|http:Response {

        // Requires : http:Request, @http:Header Annotation
        match path {
            "com" => {
                http:Response res = check exampleCom->get("/");
                return res;
            }
            "net" => {
                http:Response res = check exampleNet->get("/");
                return res;
            }
        }
        return http:NOT_FOUND;
    }

    // Option 2 - using if and with non heder binding.
    resource function get route2(http:Request req) returns http:NotFound|http:Response|error {

        // Requires : http:Request 
        string url = check req.getHeader("X-url"); // Step 2
        if url == "com" {   // Step 3
            http:Response res = check exampleCom->get("/"); // Step 4
            return res; // Step 6
        } else if url == "net" { // Step 3
            http:Response res = check exampleNet->get("/"); // Step 4
            return res; // Step 6
        }
        return http:NOT_FOUND;
    }

    // Eggplant Flow
    // ----
    // 1. Setup Endpoints
    // 2. Get Headers 
    // 3. Match Headers. (Switch/Filter)
    // 4. Make Remote Calls
    // 5. Add Error handling
    // 6. Send Response
    resource function get route3(http:Request req) returns http:NotFound|http:Response|error {

        http:Response|http:NotFound res = new;

        worker startNode {
            _ = <- function;
            () -> GetHeader;
        }

        worker GetHeader returns error? {   // Step 2
            _ = <- startNode;
            string url = check req.getHeader("X-url");
            url -> Switch;
        }

        worker Switch returns error? { // Step 3
            string url = check <- GetHeader;
            if url == "com" {
                () -> callCom;
            } else if url == "net" {
                () -> callNet;
            } else {
                () -> sendNotFound;
            }
        }

        worker callCom returns error? { // Step 4
            _ = check <- Switch;
            res = <http:Response>check exampleCom->get("/");
            io:println("Response from example.com");
            () -> sendResponse;
        }

        worker callNet returns error? { // Step 4
            _ = check <- Switch;
            res = <http:Response>check exampleNet->get("/");
            io:println("Response from example.net");
            () -> sendResponse;
        }

        worker sendNotFound returns error? { // Step 5
            _ = check <- Switch;
            res = http:NOT_FOUND;
            () -> sendResponse;
        }

        worker sendResponse {
            error? e =  <- callCom | callNet | sendNotFound; // Can't use check here.
            io:println("Returning response");
            () -> function;
        }

        () -> startNode;
        io:println("Waiting for response");
        error? e = <- sendResponse;
        io:println("Sending response");
        return res;
    }
}
