import Foundation

/// Response model for link retrieval with visit tracking
internal struct LinkRetrievalResponse: Decodable {
    let link: LinkResponse
    let visitId: String
    
    enum CodingKeys: String, CodingKey {
        case visitId = "visit_id"
    }
    
    init(from decoder: Decoder) throws {
        // Decode the visit_id separately
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.visitId = try container.decode(String.self, forKey: .visitId)
        
        // Decode the rest as LinkResponse
        self.link = try LinkResponse(from: decoder)
    }
}