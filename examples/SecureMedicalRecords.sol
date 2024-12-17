// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17; // Use the latest Solidity version

// Import the latest OpenZeppelin contracts for ERC721, AccessControl, Counters, and ECDSA
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// The SecureMedicalRecords contract inherits from ERC721 and AccessControl
contract SecureMedicalRecords is ERC721, AccessControl {
    using Counters for Counters.Counter; // Utilize Counters library for token ID management
    Counters.Counter private _tokenIds;  // Counter for tracking token IDs

    // Define roles for access control using AccessControl
    bytes32 public constant MEDICAL_INSTITUTE_ROLE = keccak256("MEDICAL_INSTITUTE_ROLE");
    bytes32 public constant PATIENT_ROLE = keccak256("PATIENT_ROLE");

    // Structure to store medical record details
    struct MedicalRecord {
        string ipfsCID; // IPFS Content Identifier for the encrypted medical record
        address owner;  // Owner of the medical record (patient's address)
    }

    // Mapping from token ID to MedicalRecord
    mapping(uint256 => MedicalRecord) private _medicalRecords;
    // Mapping from token ID to an array of AccessLogs
    mapping(uint256 => AccessLog[]) private _accessLogs;
    // Mapping to manage one-time access permissions
    mapping(uint256 => mapping(address => bool)) private _oneTimeAccess;

    // Structure to log access events with cryptographic signatures
    struct AccessLog {
        address user;      // Address of the user who accessed the record
        string action;     // Action performed (e.g., "Access Approved")
        uint256 timestamp; // Timestamp of the access event
        bytes signature;   // Cryptographic signature of the access log
    }

    // Event emitted when access to a medical record is requested
    event AccessRequested(uint256 tokenId, address requester);
    // Event emitted when access to a medical record is approved
    event AccessApproved(uint256 tokenId, address approver, address requester);

    // Constructor initializes the ERC721 token and sets up the admin role
    constructor() ERC721("SecureMedicalRecord", "SMR") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); // Grant the deployer the admin role
    }

    // Function to mint a new medical record token to a patient
    function mintRecord(address patient, string memory ipfsCID) public {
        require(hasRole(MEDICAL_INSTITUTE_ROLE, msg.sender), "Not authorized"); // Only authorized medical institutes can mint

        _tokenIds.increment(); // Increment the token ID counter
        uint256 newTokenId = _tokenIds.current(); // Get the new token ID

        // Store the medical record details in the mapping
        _medicalRecords[newTokenId] = MedicalRecord({
            ipfsCID: ipfsCID,
            owner: patient
        });

        _mint(patient, newTokenId); // Mint the ERC721 token to the patient's address
    }

    // Function for the admin to assign roles to accounts
    function assignRole(address account, bytes32 role) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin"); // Only admin can assign roles
        _grantRole(role, account); // Grant the specified role to the account
    }

    // Function for users to request access to a specific medical record token
    function requestAccess(uint256 tokenId) public {
        emit AccessRequested(tokenId, msg.sender); // Emit an event indicating access has been requested
    }

    // Function for the token owner (patient) to approve access to their medical record
    function approveAccess(uint256 tokenId, address requester) public {
        require(ownerOf(tokenId) == msg.sender, "Not token owner"); // Ensure the caller owns the token

        _oneTimeAccess[tokenId][requester] = true; // Grant one-time access to the requester

        _logAccess(tokenId, "Access Approved", requester); // Log the access approval event

        emit AccessApproved(tokenId, msg.sender, requester); // Emit an event indicating access has been approved
    }

    // View function to check if a requester has access to a specific medical record
    function hasAccess(uint256 tokenId, address requester) public view returns (bool) {
        return _oneTimeAccess[tokenId][requester]; // Return the access status
    }

    // Internal function to log access events with a cryptographic signature
    function _logAccess(uint256 tokenId, string memory action, address user) internal {
        // Create a new AccessLog struct
        AccessLog memory log = AccessLog({
            user: user,
            action: action,
            timestamp: block.timestamp, // Current block timestamp
            signature: _signLog(tokenId, action, user) // Generate a cryptographic signature for the log
        });

        _accessLogs[tokenId].push(log); // Add the log to the access logs mapping
    }

    // Internal function to generate a cryptographic signature for an access log
    function _signLog(uint256 tokenId, string memory action, address user) internal view returns (bytes memory) {
        // Hash the message containing the token ID, action, user address, and timestamp
        bytes32 messageHash = keccak256(abi.encodePacked(tokenId, action, user, block.timestamp));

        // Convert the hash to an Ethereum signed message hash
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);

        // As the contract cannot sign messages, return the hash as a placeholder
        return abi.encodePacked(ethSignedMessageHash);
    }
}