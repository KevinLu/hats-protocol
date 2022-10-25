// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Hats.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

abstract contract TestVariables {
    Hats hats;

    address[] addresses;
    uint256[] pks;

    address internal topHatWearer;
    address internal secondWearer;
    address internal thirdWearer;
    address internal fourthWearer;
    address internal nonWearer;

    uint256 internal _admin;
    string internal _details;
    uint32 internal _maxSupply;
    address internal _eligibility;
    address internal _toggle;
    string internal _baseImageURI;

    string internal topHatImageURI;
    string internal secondHatImageURI;
    string internal thirdHatImageURI;

    uint256 internal topHatId;
    uint256 internal secondHatId;
    uint256 internal thirdHatId;

    string internal name = "Hats Protocol";
    string internal version = "Test";
    bytes32 internal nameHash;
    bytes32 internal versionHash;
    uint256 internal expiry;
    uint256 internal nonce;

    uint256[] adminsBatch;
    string[] detailsBatch;
    uint32[] maxSuppliesBatch;
    address[] eligibilityModulesBatch;
    address[] toggleModulesBatch;
    string[] imageURIsBatch;

    event HatCreated(
        uint256 id,
        string details,
        uint32 maxSupply,
        address eligibility,
        address toggle,
        string imageURI
    );
    event HatRenounced(uint256 hatId, address wearer);
    event WearerStatus(
        uint256 hatId,
        address wearer,
        bool revoke,
        bool wearerStanding
    );
    event HatStatusChanged(uint256 hatId, bool newStatus);
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );
}

// test utility, drawing from oz EIP712 and ECDSA implementations
abstract contract EIP712Tests {
    // EIP712 state
    bytes32 private immutable _TYPE_HASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    // ECDSA functions

    function _toTypedDataHash(bytes32 domainSeparator, bytes32 structHash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked("\x19\x01", domainSeparator, structHash)
            );
    }

    // EIP712 functions

    function _buildDomainSeparator(
        bytes32 nameHash,
        bytes32 versionHash,
        address thisContract
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _TYPE_HASH,
                    nameHash,
                    versionHash,
                    block.chainid,
                    thisContract
                )
            );
    }

    function hashTypedDataV4(
        bytes32 nameHash,
        bytes32 versionHash,
        address thisContract,
        bytes32 structHash
    ) public view virtual returns (bytes32) {
        return
            _toTypedDataHash(
                _buildDomainSeparator(nameHash, versionHash, thisContract),
                structHash
            );
    }
}

abstract contract TestSetup is Test, TestVariables, EIP712Tests {
    function setUp() public virtual {
        setUpVariables();
        // instantiate Hats contract
        hats = new Hats(version, _baseImageURI);

        // create TopHat
        createTopHat();
    }

    function createAddressesFromPks(uint256 count)
        public
        returns (uint256[] memory pks_, address[] memory addresses_)
    {
        pks_ = new uint256[](count);
        addresses_ = new address[](count);

        for (uint256 i = 0; i < count; ++i) {
            pks_[i] = 100 * (i + 1);
            addresses_[i] = vm.addr(pks_[i]);
        }
    }

    function setUpVariables() internal {
        // set variables: deploy
        _baseImageURI = "https://www.images.hats.work/";

        (pks, addresses) = createAddressesFromPks(5);

        // set variables: addresses
        topHatWearer = addresses[0];
        secondWearer = addresses[1];
        thirdWearer = addresses[2];
        fourthWearer = addresses[3];
        nonWearer = addresses[4];

        // set variables: Hat parameters
        _maxSupply = 1;
        _eligibility = address(555);
        _toggle = address(333);

        topHatImageURI = "http://www.tophat.com/";
        secondHatImageURI = "http://www.second.com/";
        thirdHatImageURI = "http://www.third.com/";

        name = "Hats Protocol";
        version = "Test";
        nameHash = keccak256(bytes(name));
        versionHash = keccak256(bytes(version));
    }

    function createTopHat() internal {
        // create TopHat
        topHatId = hats.mintTopHat(topHatWearer, "http://www.tophat.com/");
    }

    /// @dev assumes a tophat has already been created
    /// @dev doesn't apply any imageURIs
    function createHatsBranch(
        uint256 _length,
        uint256 _topHatId,
        address _topHatWearer
    ) internal returns (uint256[] memory ids, address[] memory wearers) {
        uint256 id;
        address wearer;
        uint256 admin;
        address adminWearer;

        ids = new uint256[](_length);
        wearers = new address[](_length);

        for (uint256 i = 0; i < _length; ++i) {
            admin = (i == 0) ? _topHatId : ids[i - 1];

            adminWearer = (i == 0) ? _topHatWearer : wearers[i - 1];

            // create ith hat from the admin
            vm.prank(adminWearer);

            id = hats.createHat(
                admin,
                string.concat("hat ", vm.toString(i + 2)),
                _maxSupply,
                _eligibility,
                _toggle,
                "" // imageURI
            );
            ids[i] = id;

            // mint ith hat from the admin, to the ith wearer
            vm.prank(adminWearer);
            wearer = address(uint160(i));
            hats.mintHat(id, wearer);

            wearers[i] = wearer;
        }
    }
}

// in addition to TestSetup, TestSetup2 creates and mints a second hat
abstract contract TestSetup2 is TestSetup {
    function setUp() public override {
        // expand on TestSetup
        super.setUp();

        // create second Hat
        vm.prank(topHatWearer);
        secondHatId = hats.createHat(
            topHatId,
            "second hat",
            2, // maxSupply
            _eligibility,
            _toggle,
            secondHatImageURI
        );

        // mint second hat
        vm.prank(address(topHatWearer));
        hats.mintHat(secondHatId, secondWearer);
    }
}

abstract contract TestSetupBatch is TestSetup {
    function setUp() public override {
        // expand on TestSetup
        super.setUp();

        // create empty batch create arrays
    }
}
