// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Registrasi Hak Cipta Karya Multimedia
/// @notice Mengelola pencatatan hak cipta digital berbasis IPFS dengan kontrol akses
contract MediaCopyrightRegistry {
    
    // Custom Error untuk efisiensi Gas
    error UnauthorizedAccess(address caller);
    error MediaAlreadyExists(bytes32 mediaId);
    error MediaNotFound(bytes32 mediaId);
    
    // TAMBAHAN: Custom error untuk kegagalan akses saat transfer hak cipta
    error NotMediaOwner(address caller);

    enum MediaType { Image, Audio, Video, Model3D }
    
    // TUGAS 2: Update struct metadata karya multimedia untuk menyimpan histori
    struct MediaWork {
        bytes32 mediaId;
        string title;
        string ipfsHash;
        MediaType mediaType;
        address creator;            // Pencipta awal
        address currentOwner;       // TAMBAHAN: Pemilik hak cipta saat ini
        uint256 timestamp;
        bool isVerified;
        address[] ownershipHistory; // TAMBAHAN: Menyimpan histori perubahan kepemilikan
    }
    
    address public admin;
    
    // Storage mappings
    mapping(bytes32 => MediaWork) private registry;
    mapping(address => bytes32[]) private creatorPortfolio;
    
    // Events
    event MediaRegistered(bytes32 indexed mediaId, address indexed creator, string ipfsHash);
    event MediaVerified(bytes32 indexed mediaId, address indexed verifier);
    event CopyrightTransferred(bytes32 indexed mediaId, address indexed oldOwner, address indexed newOwner);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert UnauthorizedAccess(msg.sender);
        _;
    }

    // TAMBAHAN TUGAS 1: Modifier untuk memastikan hanya pemilik saat ini yang bisa akses
    modifier onlyCreator(bytes32 _mediaId) {
        if (registry[_mediaId].timestamp == 0) revert MediaNotFound(_mediaId);
        if (msg.sender != registry[_mediaId].currentOwner) revert NotMediaOwner(msg.sender);
        _;
    }

    constructor() {
        admin = msg.sender;
    }
    
    /// @dev Mendaftarkan hak cipta media baru
    function registerMedia(
        string calldata _title,
        string calldata _ipfsHash,
        MediaType _mediaType
    ) external returns (bytes32) {
        require(bytes(_title).length > 0, "Judul tidak boleh kosong");
        require(bytes(_ipfsHash).length > 0, "IPFS Hash wajib diisi");
        
        bytes32 mediaId = keccak256(abi.encodePacked(msg.sender, _ipfsHash, block.timestamp));
        if (registry[mediaId].timestamp != 0) revert MediaAlreadyExists(mediaId);
        
        // Array kosong sebagai inisialisasi awal histori
        address[] memory emptyHistory;

        MediaWork memory newWork = MediaWork({
            mediaId: mediaId,
            title: _title,
            ipfsHash: _ipfsHash,
            mediaType: _mediaType,
            creator: msg.sender,
            currentOwner: msg.sender, // Pemilik awal adalah pendaftar
            timestamp: block.timestamp,
            isVerified: false,
            ownershipHistory: emptyHistory
        });
        
        registry[mediaId] = newWork;
        creatorPortfolio[msg.sender].push(mediaId);
        
        emit MediaRegistered(mediaId, msg.sender, _ipfsHash);
        return mediaId;
    }
    
    /// @dev Verifikasi karya oleh Admin
    function verifyMedia(bytes32 _mediaId) external onlyAdmin {
        if (registry[_mediaId].timestamp == 0) revert MediaNotFound(_mediaId);
        registry[_mediaId].isVerified = true;
        emit MediaVerified(_mediaId, msg.sender);
    }

    /// @dev TAMBAHAN TUGAS 1: Memindahkan hak kepemilikan karya
    function transferCopyright(bytes32 _mediaId, address _newOwner) external onlyCreator(_mediaId) {
        require(_newOwner != address(0), "Alamat baru tidak valid");
        require(_newOwner != msg.sender, "Tidak bisa mentransfer ke diri sendiri");

        MediaWork storage work = registry[_mediaId];
        
        // Simpan pemilik lama ke dalam histori kepemilikan
        work.ownershipHistory.push(work.currentOwner);
        
        address oldOwner = work.currentOwner;
        
        // Ubah pemilik saat ini menjadi pemilik baru
        work.currentOwner = _newOwner;

        // Opsional: Tambahkan karya ini ke portofolio pemilik yang baru
        creatorPortfolio[_newOwner].push(_mediaId);

        emit CopyrightTransferred(_mediaId, oldOwner, _newOwner);
    }
    
    /// @dev Membaca metadata media (Read-Only / Gasless)
    function getMedia(bytes32 _mediaId) external view returns (MediaWork memory) {
        if (registry[_mediaId].timestamp == 0) revert MediaNotFound(_mediaId);
        return registry[_mediaId];
    }
    
    /// @dev Mengambil daftar ID karya milik pencipta
    function getCreatorPortfolio(address _creator) external view returns (bytes32[] memory) {
        return creatorPortfolio[_creator];
    }
}
