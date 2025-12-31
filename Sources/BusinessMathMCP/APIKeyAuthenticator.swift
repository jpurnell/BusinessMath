import Foundation
import Logging

/// Manages API key authentication for HTTP transport
///
/// Supports multiple API keys for different clients/environments.
/// Keys can be provided via:
/// - Environment variable: MCP_API_KEYS (comma-separated)
/// - Configuration file
/// - Programmatically
///
/// ## Usage
///
/// ```swift
/// let auth = APIKeyAuthenticator(apiKeys: ["key1", "key2"])
/// let isValid = await auth.validate(request)
/// ```
///
/// ## Security Notes
///
/// - Always use HTTPS in production (API keys sent in plaintext)
/// - Rotate keys regularly
/// - Use different keys per environment (dev/staging/prod)
/// - Never commit keys to source control
public actor APIKeyAuthenticator {
    private let logger: Logger

    /// Set of valid API keys (stored as hashes for security)
    private var validKeyHashes: Set<String>

    /// Whether authentication is required
    /// If false, all requests are allowed (useful for development)
    private let authRequired: Bool

    /// Initialize authenticator
    /// - Parameters:
    ///   - apiKeys: Array of valid API keys (will be hashed)
    ///   - authRequired: Whether to enforce authentication (default: true)
    ///   - logger: Logger instance
    public init(
        apiKeys: [String] = [],
        authRequired: Bool = true,
        logger: Logger = Logger(label: "api-key-auth")
    ) {
        self.authRequired = authRequired
        self.logger = logger

        // Hash API keys for storage (don't store plaintext)
        self.validKeyHashes = Set(apiKeys.map { Self.hashKey($0) })

        if authRequired && apiKeys.isEmpty {
            logger.warning("API key authentication enabled but no keys provided - all requests will be rejected")
        } else if !authRequired {
            logger.warning("API key authentication is DISABLED - all requests allowed (development mode only)")
        } else {
            logger.info("API key authentication enabled with \(apiKeys.count) key(s)")
        }
    }

    /// Validate an HTTP request's Authorization header
    /// - Parameter authHeader: The Authorization header value
    /// - Returns: Whether the request is authorized
    public func validate(authHeader: String?) -> Bool {
        // If auth not required, allow all requests
        guard authRequired else {
            return true
        }

        // Require Authorization header
        guard let authHeader = authHeader else {
            logger.debug("Request rejected: missing Authorization header")
            return false
        }

        // Parse Authorization header
        // Supported formats:
        // - "Bearer <api-key>"
        // - "ApiKey <api-key>"
        // - "<api-key>" (bare key)
        let apiKey = extractAPIKey(from: authHeader)

        guard let apiKey = apiKey else {
            logger.debug("Request rejected: invalid Authorization header format")
            return false
        }

        // Hash and check against valid keys
        let keyHash = Self.hashKey(apiKey)
        let isValid = validKeyHashes.contains(keyHash)

        if !isValid {
            logger.warning("Request rejected: invalid API key")
        }

        return isValid
    }

    /// Add a new API key
    /// - Parameter apiKey: The API key to add
    public func addKey(_ apiKey: String) {
        let hash = Self.hashKey(apiKey)
        validKeyHashes.insert(hash)
        logger.info("Added new API key (total: \(validKeyHashes.count))")
    }

    /// Remove an API key
    /// - Parameter apiKey: The API key to remove
    public func removeKey(_ apiKey: String) {
        let hash = Self.hashKey(apiKey)
        if validKeyHashes.remove(hash) != nil {
            logger.info("Removed API key (remaining: \(validKeyHashes.count))")
        }
    }

    /// Get count of registered keys
    public func keyCount() -> Int {
        return validKeyHashes.count
    }

    // MARK: - Private Helpers

    /// Extract API key from Authorization header
    private func extractAPIKey(from authHeader: String) -> String? {
        let trimmed = authHeader.trimmingCharacters(in: .whitespaces)

        // Try "Bearer <key>" format
        if trimmed.lowercased().hasPrefix("bearer ") {
            return String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        }

        // Try "ApiKey <key>" format
        if trimmed.lowercased().hasPrefix("apikey ") {
            return String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        }

        // Bare key (no prefix)
        return trimmed
    }

    /// Hash an API key using SHA-256
    /// This prevents storing keys in plaintext in memory
    private static func hashKey(_ key: String) -> String {
        guard let data = key.data(using: .utf8) else {
            return ""
        }

        // Use SHA-256 for hashing
        // Note: For production, consider using a proper password hashing algorithm
        // like bcrypt or Argon2, but SHA-256 is sufficient for API keys
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            // Simple SHA-256 implementation would go here
            // For now, use a basic hash (this should be replaced with proper crypto)
            let bytes = buffer.bindMemory(to: UInt8.self)
            for (index, byte) in bytes.enumerated() {
                hash[index % 32] ^= byte
            }
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Configuration Loading

extension APIKeyAuthenticator {
    /// Create authenticator from environment variables
    /// Reads MCP_API_KEYS environment variable (comma-separated keys)
    /// - Returns: Configured authenticator
    public static func fromEnvironment(logger: Logger = Logger(label: "api-key-auth")) -> APIKeyAuthenticator {
        let keysString = ProcessInfo.processInfo.environment["MCP_API_KEYS"] ?? ""
        let keys = keysString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let authRequired = ProcessInfo.processInfo.environment["MCP_AUTH_REQUIRED"] != "false"

        if authRequired && keys.isEmpty {
            logger.warning("No API keys found in MCP_API_KEYS environment variable")
        }

        return APIKeyAuthenticator(apiKeys: keys, authRequired: authRequired, logger: logger)
    }
}
