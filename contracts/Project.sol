// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Land Title Registry (basic)
/// @notice Simple land registry allowing authorized registrars to register lands,
///         owners to update metadata, and owners to transfer ownership.
/// @dev Uses OpenZeppelin Ownable for admin; Counters for id generation.

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract LandTitleRegistry is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _landIdCounter;

    struct Land {
        uint256 id;            // unique land id
        address owner;         // current owner
        string location;       // human-friendly address or description
        uint256 area;          // area in square feet (or smallest unit chosen)
        string docHash;        // IPFS / hash of deed or metadata
        bool exists;           // if record exists
    }

    // landId => Land
    mapping(uint256 => Land) private lands;

    // address => isRegistrar
    mapping(address => bool) public registrars;

    // Events
    event RegistrarAdded(address indexed registrar);
    event RegistrarRemoved(address indexed registrar);
    event LandRegistered(uint256 indexed landId, address indexed owner);
    event OwnershipTransferred(uint256 indexed landId, address indexed from, address indexed to);
    event LandMetadataUpdated(uint256 indexed landId, address indexed updater, string newDocHash);

    // Modifiers
    modifier onlyRegistrar() {
        require(registrars[msg.sender], "Not an authorized registrar");
        _;
    }

    modifier landExists(uint256 landId) {
        require(lands[landId].exists, "Land does not exist");
        _;
    }

    modifier onlyLandOwner(uint256 landId) {
        require(lands[landId].owner == msg.sender, "Only land owner can call");
        _;
    }

    constructor() {
        // Owner (deployer) is implicitly an admin via Ownable
    }

    // Admin functions (onlyOwner)
    function addRegistrar(address registrar) external onlyOwner {
        require(registrar != address(0), "Zero address");
        require(!registrars[registrar], "Already registrar");
        registrars[registrar] = true;
        emit RegistrarAdded(registrar);
    }

    function removeRegistrar(address registrar) external onlyOwner {
        require(registrars[registrar], "Not a registrar");
        registrars[registrar] = false;
        emit RegistrarRemoved(registrar);
    }

    // Registrar registers a new land record (mint-like)
    function registerLand(
        address owner_,
        string calldata location_,
        uint256 area_,
        string calldata docHash_
    ) external onlyRegistrar returns (uint256) {
        require(owner_ != address(0), "Invalid owner");

        _landIdCounter.increment();
        uint256 newId = _landIdCounter.current();

        lands[newId] = Land({
            id: newId,
            owner: owner_,
            location: location_,
            area: area_,
            docHash: docHash_,
            exists: true
        });

        emit LandRegistered(newId, owner_);
        return newId;
    }

    // Transfer ownership (initiated by current owner)
    function transferOwnershipOfLand(uint256 landId, address to)
        external
        landExists(landId)
        onlyLandOwner(landId)
    {
        require(to != address(0), "Invalid recipient");
        address from = lands[landId].owner;
        lands[landId].owner = to;
        emit OwnershipTransferred(landId, from, to);
    }

    // Owner updates the docHash (e.g., new deed IPFS hash)
    function updateLandDocHash(uint256 landId, string calldata newDocHash)
        external
        landExists(landId)
        onlyLandOwner(landId)
    {
        lands[landId].docHash = newDocHash;
        emit LandMetadataUpdated(landId, msg.sender, newDocHash);
    }

    // Admin can forcibly change owner in exceptional cases (e.g., court order)
    function adminChangeOwner(uint256 landId, address newOwner)
        external
        onlyOwner
        landExists(landId)
    {
        require(newOwner != address(0), "Invalid address");
        address prev = lands[landId].owner;
        lands[landId].owner = newOwner;
        emit OwnershipTransferred(landId, prev, newOwner);
    }

    // View helpers
    function getLand(uint256 landId) external view landExists(landId) returns (
        uint256 id,
        address owner,
        string memory location,
        uint256 area,
        string memory docHash
    ) {
        Land storage l = lands[landId];
        return (l.id, l.owner, l.location, l.area, l.docHash);
    }

    function totalLands() external view returns (uint256) {
        return _landIdCounter.current();
    }

    // Convenience: check if an address is registrar
    function isRegistrar(address addr) external view returns (bool) {
        return registrars[addr];
    }
}
