// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import "../src/L2ArbitrumToken.sol";

import "./TestUtil.sol";
import "forge-std/Test.sol";

contract L2ArbitrumTokenTest is Test {
    address owner = address(1);
    address l1Token = address(2);
    address mintRecipient = address(3);
    address user = address(4);
    uint256 initialSupply = 10 * 1_000_000_000 * (10 ** 18);

    function deploy() private returns (L2ArbitrumToken l2Token, address l2Gateway) {
        address proxy = TestUtil.deployProxy(address(new L2ArbitrumToken()));
        l2Token = L2ArbitrumToken(proxy);

        l2Gateway = deployCode("L2ReverseCustomGateway.sol:L2ReverseCustomGateway");
    }

    function deployAndInit() private returns (L2ArbitrumToken l2Token, address l2Gateway) {
        (l2Token, l2Gateway) = deploy();

        l2Token.initialize(l2Gateway, l1Token, initialSupply, owner);
    }

    function testIsInitialised() public {
        (L2ArbitrumToken l2Token, address l2Gateway) = deployAndInit();

        assertEq(l2Token.name(), "Arbitrum", "Invalid name");
        assertEq(l2Token.symbol(), "ARB", "Invalid symbol");
        assertEq(l2Token.l2Gateway(), l2Gateway, "Invalid l2Gateway");
        assertEq(l2Token.l1Address(), l1Token, "Invalid l1Address");
        assertEq(l2Token.nextMint(), block.timestamp + l2Token.MIN_MINT_INTERVAL(), "Invalid nextMint");
        assertEq(l2Token.totalSupply(), 1e28, "Invalid totalSupply");
        assertEq(l2Token.owner(), owner, "Invalid owner");
    }

    function testDoesNotInitialiseZeroL2Gateway() public {
        (L2ArbitrumToken l2Token,) = deploy();

        vm.expectRevert("ARB: ZERO_L2GATEWAY");
        l2Token.initialize(address(0), l1Token, initialSupply, owner);
    }

    function testDoesNotInitialiseZeroL1Token() public {
        (L2ArbitrumToken l2Token, address l2Gateway) = deploy();

        vm.expectRevert("ARB: ZERO_L1TOKEN_ADDRESS");
        l2Token.initialize(l2Gateway, address(0), initialSupply, owner);
    }

    function testDoesNotInitialiseZeroInitialSup() public {
        (L2ArbitrumToken l2Token, address l2Gateway) = deploy();

        vm.expectRevert("ARB: ZERO_INITIAL_SUPPLY");
        l2Token.initialize(l2Gateway, l1Token, 0, owner);
    }

    function testDoesNotInitialiseZeroOwner() public {
        (L2ArbitrumToken l2Token, address l2Gateway) = deploy();

        vm.expectRevert("ARB: ZERO_OWNER");
        l2Token.initialize(l2Gateway, l1Token, initialSupply, address(0));
    }

    function validMint(uint256 supplyNumerator, string memory revertReason, bool warp, address minter) public {
        (L2ArbitrumToken l2Token,) = deployAndInit();

        uint256 additionalSupply = initialSupply * supplyNumerator / 100_000;

        assertEq(l2Token.balanceOf(mintRecipient), 0, "Invalid initial balance");

        if (warp) {
            vm.warp(block.timestamp + l2Token.MIN_MINT_INTERVAL());
        }
        vm.prank(minter);
        if (bytes(revertReason).length != 0) {
            vm.expectRevert(bytes(revertReason));
            l2Token.mint(mintRecipient, additionalSupply);
        } else {
            l2Token.mint(mintRecipient, additionalSupply);
            assertEq(l2Token.totalSupply(), initialSupply + additionalSupply, "Invalid inflated supply");
            assertEq(l2Token.balanceOf(mintRecipient), additionalSupply, "Invalid final balance");
        }
    }

    function testCanMintLessThan2Percent() public {
        validMint(1357, "", true, owner);
    }

    function testCanMint2Percent() public {
        validMint(2000, "", true, owner);
    }

    function testCanMintZero() public {
        validMint(0, "", true, owner);
    }

    function testCannotMintMoreThan2Percent() public {
        validMint(2001, "ARB: MINT_TOO_MUCH", true, owner);
    }

    function testCannotMintWithoutFastForward() public {
        validMint(2000, "ARB: MINT_TOO_EARLY", false, owner);
    }

    function testCannotMintNotOwner() public {
        validMint(2000, "Ownable: caller is not the owner", false, mintRecipient);
    }

    function testCannotMintTwice() public {
        validMint(1357, "", true, owner);
        validMint(1357, "ARB: MINT_TOO_EARLY", false, owner);
    }

    function testCanMintTwiceWithWarp() public {
        validMint(1357, "", true, owner);
        validMint(1357, "", true, owner);
    }
}