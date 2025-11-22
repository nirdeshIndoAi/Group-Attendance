import Foundation
import CryptoKit

class FaceRecognitionNative {
    static let shared = FaceRecognitionNative()
    
    private let integritySecret = "GA_NATIVE_SECURE_SALT_2024"
    private var isTampered = false
    private var integrityChecksum: UInt64 = 0
    private var isLicenseValidated = false
    private var lastLicenseValidationTime: TimeInterval = 0
    private let licenseValidationInterval: TimeInterval = 3600
    
    private init() {
        integrityChecksum = computeClassChecksum()
    }
    
    func initialize() -> Int32 {
        if !verifyIntegrityChecksum() {
            isTampered = true
            return -1
        }
        return 0
    }
    
    func validateLicense(licenseKey: String, appId: String, endpoint: String) -> Int32 {
        if isTampered || !verifyIntegrityChecksum() || !checkAntiTampering() {
            return -2
        }
        
        if !isLicenseValidated || !isLicenseStillValid() {
            let isValid = validateLicenseInternal(licenseKey: licenseKey, appId: appId, endpoint: endpoint)
            if isValid {
                isLicenseValidated = true
                lastLicenseValidationTime = Date().timeIntervalSince1970
                return 0
            } else {
                return -3
            }
        }
        return 0
    }
    
    func compareTemplates(template1: Data, template2: Data) -> [String: Double] {
        if !isLicenseValidated || !isLicenseStillValid() || isTampered {
            return [
                "final": 0.0,
                "cosine": 0.0,
                "distance": 0.0,
                "exactMatch": 0.0,
                "correlation": 0.0,
            ]
        }
        
        return compareTemplatesInternal(template1: template1, template2: template2)
    }
    
    func verifyIntegrity(challenge: String) -> String {
        if isTampered || !verifyIntegrityChecksum() {
            return "TAMPERED"
        }
        let combined = challenge + integritySecret
        let digest = SHA256.hash(data: Data(combined.utf8))
        return Data(digest).base64EncodedString()
    }
    
    private func validateLicenseInternal(licenseKey: String, appId: String, endpoint: String) -> Bool {
        if isTampered || !verifyIntegrityChecksum() || !checkAntiTampering() {
            return false
        }
        
        guard let url = URL(string: decryptEndpoint(endpoint)) else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("GroupAttendanceSDK/1.0.0", forHTTPHeaderField: "User-Agent")
        request.setValue(licenseKey, forHTTPHeaderField: "Api-Key")
        let body = "app_id=\(appId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")"
        request.httpBody = body.data(using: .utf8)
        
        var isValid = false
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            defer { semaphore.signal() }
            
            guard let self = self,
                  error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data,
                  let bodyString = String(data: data, encoding: .utf8) else {
                isValid = false
                return
            }
            
            if !self.verifyIntegrityChecksum() {
                isValid = false
                return
            }
            
            isValid = self.isResponseValid(bodyString)
        }.resume()
        
        semaphore.wait()
        
        if isValid {
            isLicenseValidated = true
            lastLicenseValidationTime = Date().timeIntervalSince1970
        }
        
        return isValid
    }
    
    private func compareTemplatesInternal(template1: Data, template2: Data) -> [String: Double] {
        let minLength = min(template1.count, template2.count)
        let trimmed1 = template1.prefix(minLength)
        let trimmed2 = template2.prefix(minLength)
        
        var dotProduct = 0.0
        var norm1 = 0.0
        var norm2 = 0.0
        
        for i in 0..<minLength {
            let val1 = Double(trimmed1[i] & 0xFF)
            let val2 = Double(trimmed2[i] & 0xFF)
            dotProduct += val1 * val2
            norm1 += val1 * val1
            norm2 += val2 * val2
        }
        
        var cosineSimilarity = 0.0
        if norm1 > 0 && norm2 > 0 {
            cosineSimilarity = dotProduct / (sqrt(norm1) * sqrt(norm2))
        }
        
        var euclideanDistance = 0.0
        for i in 0..<minLength {
            let diff = Double(trimmed1[i] & 0xFF) - Double(trimmed2[i] & 0xFF)
            euclideanDistance += diff * diff
        }
        euclideanDistance = sqrt(euclideanDistance)
        
        let maxPossibleDistance = sqrt(Double(minLength) * 255.0 * 255.0)
        let normalizedDistance = 1.0 - (euclideanDistance / maxPossibleDistance)
        
        var exactMatches = 0
        for i in 0..<minLength {
            if abs(Double(trimmed1[i] & 0xFF) - Double(trimmed2[i] & 0xFF)) < 15 {
                exactMatches += 1
            }
        }
        let exactMatchRatio = Double(exactMatches) / Double(minLength)
        
        var sum1 = 0.0
        var sum2 = 0.0
        for i in 0..<minLength {
            sum1 += Double(trimmed1[i] & 0xFF)
            sum2 += Double(trimmed2[i] & 0xFF)
        }
        let mean1 = sum1 / Double(minLength)
        let mean2 = sum2 / Double(minLength)
        
        var correlation = 0.0
        var std1 = 0.0
        var std2 = 0.0
        for i in 0..<minLength {
            let diff1 = Double(trimmed1[i] & 0xFF) - mean1
            let diff2 = Double(trimmed2[i] & 0xFF) - mean2
            correlation += diff1 * diff2
            std1 += diff1 * diff1
            std2 += diff2 * diff2
        }
        
        var pearsonCorrelation = 0.0
        if std1 > 0 && std2 > 0 {
            pearsonCorrelation = correlation / (sqrt(std1) * sqrt(std2))
            pearsonCorrelation = (pearsonCorrelation + 1.0) / 2.0
        }
        
        var finalSimilarity = cosineSimilarity * 0.40 +
            normalizedDistance * 0.30 +
            exactMatchRatio * 0.20 +
            pearsonCorrelation * 0.10
        finalSimilarity = max(0.0, min(1.0, finalSimilarity))
        
        return [
            "final": finalSimilarity,
            "cosine": cosineSimilarity,
            "distance": normalizedDistance,
            "exactMatch": exactMatchRatio,
            "correlation": pearsonCorrelation,
        ]
    }
    
    private func isResponseValid(_ body: String) -> Bool {
        if let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let successKeys = ["success", "status", "valid", "is_valid", "authorized"]
            for key in successKeys {
                if let value = json[key] as? Bool, value {
                    return true
                }
            }
            if let message = json["message"] as? String,
               message.lowercased().contains("valid") {
                return true
            }
        } else if body.lowercased().contains("valid") {
            return true
        }
        return false
    }
    
    private func decryptEndpoint(_ encrypted: String) -> String {
        guard !encrypted.isEmpty,
              let decoded = Data(base64Encoded: encrypted),
              let keyData = integritySecret.data(using: .utf8) else {
            return encrypted
        }
        
        var decrypted = Data()
        let keyBytes = Array(keyData)
        for (index, byte) in decoded.enumerated() {
            let keyByte = keyBytes[index % keyBytes.count]
            decrypted.append(byte ^ keyByte)
        }
        
        return String(data: decrypted, encoding: .utf8) ?? encrypted
    }
    
    private func computeClassChecksum() -> UInt64 {
        let className = String(describing: Self.self)
        guard let data = className.data(using: .utf8) else {
            return 0xDEADBEEF
        }
        
        var checksum: UInt64 = 0
        for byte in data {
            checksum = (checksum << 8) | UInt64(byte)
            checksum &= 0xFFFFFFFF
        }
        return checksum
    }
    
    private func verifyIntegrityChecksum() -> Bool {
        let current = computeClassChecksum()
        if integrityChecksum == 0 {
            integrityChecksum = current
            return true
        }
        return current == integrityChecksum
    }
    
    private func checkAntiTampering() -> Bool {
        return verifyIntegrityChecksum()
    }
    
    private func isLicenseStillValid() -> Bool {
        if !isLicenseValidated {
            return false
        }
        let currentTime = Date().timeIntervalSince1970
        let timeSinceValidation = currentTime - lastLicenseValidationTime
        return timeSinceValidation < licenseValidationInterval
    }
}

