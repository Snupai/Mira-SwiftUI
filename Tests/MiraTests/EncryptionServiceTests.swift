import XCTest
@testable import Mira

/// Round-trip + tamper-rejection tests for `EncryptionService`.
///
/// These tests touch the macOS Keychain (login keychain, non-iCloud-synced for tests).
/// If your CI environment doesn't allow keychain access, mark these as expected
/// failures or skip via `XCTSkipIf(!EncryptionService.shared.hasKey)`.
final class EncryptionServiceTests: XCTestCase {

    private let service = EncryptionService.shared

    override func setUp() {
        super.setUp()
        // Use local-only encryption for tests so we don't pollute iCloud Keychain.
        service.useiCloudKeychain = false
    }

    // MARK: - Round-trip

    func testStringRoundTrip() throws {
        let plaintext = "DE89 3704 0044 0532 0130 00"
        let ciphertext = try service.encrypt(plaintext)

        XCTAssertNotEqual(ciphertext, plaintext, "ciphertext must not equal plaintext")
        XCTAssertFalse(ciphertext.isEmpty)

        let decrypted = try service.decrypt(ciphertext)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testEmptyStringRoundTripIsNoOp() throws {
        let ciphertext = try service.encrypt("")
        XCTAssertEqual(ciphertext, "", "encrypt('') must return '' (no-op)")
        XCTAssertEqual(try service.decrypt(""), "", "decrypt('') must return '' (no-op)")
    }

    func testDataRoundTrip() throws {
        let plaintext = Data("sensitive payload".utf8)
        let ciphertext = try service.encrypt(plaintext)

        XCTAssertNotEqual(ciphertext, plaintext)
        XCTAssertFalse(ciphertext.isEmpty)

        let decrypted = try service.decrypt(ciphertext)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testEmptyDataRoundTripIsNoOp() throws {
        let ciphertext = try service.encrypt(Data())
        XCTAssertEqual(ciphertext, Data())
        XCTAssertEqual(try service.decrypt(Data()), Data())
    }

    func testMultipleEncryptionsProduceDifferentCiphertexts() throws {
        // AES-GCM uses a fresh nonce per call → ciphertexts must differ even for the same input.
        let plaintext = "constant"
        let a = try service.encrypt(plaintext)
        let b = try service.encrypt(plaintext)
        XCTAssertNotEqual(a, b, "AES-GCM should produce a unique nonce each call")

        XCTAssertEqual(try service.decrypt(a), plaintext)
        XCTAssertEqual(try service.decrypt(b), plaintext)
    }

    // MARK: - Tamper detection

    func testTamperedCiphertextIsRejected() throws {
        let original = try service.encrypt("important")
        // Flip a byte in the middle of the Base64 ciphertext to invalidate the GCM tag.
        var bytes = Array(original.utf8)
        let mid = bytes.count / 2
        bytes[mid] = bytes[mid] == UInt8(ascii: "A") ? UInt8(ascii: "B") : UInt8(ascii: "A")
        let tampered = String(decoding: bytes, as: UTF8.self)

        XCTAssertThrowsError(try service.decrypt(tampered),
                             "tampered ciphertext must throw, not silently return garbage")
    }

    func testInvalidBase64IsRejected() {
        XCTAssertThrowsError(try service.decrypt("!!! not base64 !!!"))
    }

    func testEmptyDataDecryptOfNonEmptyCiphertextThrows() throws {
        // An obviously-too-short Data should not be accepted as a valid SealedBox.
        let shortBytes = Data(repeating: 0x00, count: 4)
        XCTAssertThrowsError(try service.decrypt(shortBytes))
    }
}
