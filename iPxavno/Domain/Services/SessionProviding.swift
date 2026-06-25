import Foundation

protocol SessionProviding {
    var currentCredential: AuthCredential? { get }
}
