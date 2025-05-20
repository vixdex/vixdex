// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {HuffDeployer} from "foundry-huff/HuffDeployer.sol";

contract DeployScript is Script {
    function run() public {
        vm.startBroadcast(); // starts broadcasting txs from the default private key (or .env)
        address deployed = HuffDeployer.deploy("BondingCurve");
        console2.log("BondingCurve deployed at:", deployed);
        vm.stopBroadcast();
    }
}
