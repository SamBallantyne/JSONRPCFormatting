import Foundation

public struct JSONRPCRequest<JSONRPCParam : Encodable> : Encodable {
    var jsonrpc : String
    var id : Int
    var method: String
    var params : JSONRPCParam
}

public struct JSONRPCError : Codable {
    var code : Int
    var message : String
}

public struct JSONRPCResultResponse<JSONRPCResult : Decodable> : Decodable {
    var jsonrpc : String
    var id : Int
    var result : JSONRPCResult
}

public struct JSONRPCErrorResponse : Codable {
    var jsonrpc : String
    var id : Int
    var error : JSONRPCError
}

public func invocationRequest<JSONRPCParams>(url: String, method: String, params : JSONRPCParams, encoder: JSONEncoder = JSONEncoder()) -> URLRequest where JSONRPCParams : Encodable {
    let requestBody = JSONRPCRequest(jsonrpc: "2.0", id: 0, method: method, params: params)
    let jsonData = try! encoder.encode(requestBody)
    var request = URLRequest(url: URL(string: url)!)
    request.httpBody = jsonData
    request.httpMethod = "POST"
    return request
}

public func invocationTask<JSONRPCParams, JSONRPCResult>(in session: URLSession, to url: String, method: String, params: JSONRPCParams, completion: @escaping ((_ error : JSONRPCError?, _ result : JSONRPCResult?) -> Void)) -> URLSessionUploadTask where JSONRPCParams : Encodable, JSONRPCResult : Decodable {
    
    let request = invocationRequest(url: url, method: method, params: params)
    return session.uploadTask(with: request, from: request.httpBody!) { (responseData, httResponse, httpError) in
        
        DispatchQueue.main.async {
            
            guard httpError == nil else {
                completion(JSONRPCError(code: 0, message: httpError!.localizedDescription), nil)
                return
            }
            
            guard responseData != nil else {
                completion(JSONRPCError(code: 0, message: "Empty server response."), nil)
                return
            }
            
            let decoder = JSONDecoder()
            if let jsonrpcError = try? decoder.decode(JSONRPCErrorResponse.self, from: responseData!) {
                completion(jsonrpcError.error, nil)
                return
            }
            
            if let expectedResponse = try? decoder.decode(JSONRPCResultResponse<JSONRPCResult>.self, from: responseData!) {
                completion(nil, expectedResponse.result)
                return
            }
            
            let responseAsString = String(data: responseData!, encoding: .utf8)
            completion(JSONRPCError(code: 0, message: responseAsString!), nil)
        }
    }
}
