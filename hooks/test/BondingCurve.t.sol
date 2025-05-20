// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {HuffDeployer} from "foundry-huff/HuffDeployer.sol";
import {Test,console} from "forge-std/Test.sol";
import {IBondingCurve} from "../src/interfaces/IBondingCurve.sol";
contract helloTest is Test{
IBondingCurve public curve;
function setUp() public {
    curve = IBondingCurve(HuffDeployer.deploy("BondingCurve"));
    console.log("bonding curve contract deployed at:", address(curve));
}

function testPrice() public {
    uint slope = 0.03 * 1e18;
    uint circulation = 1000;
    uint basePrice = 0.1 * 1e18;
    uint price = curve.settingPrice(slope, circulation, basePrice);
    console.log("Price is:", price);
}

function testCostOfPurchasingToken() public {
    uint gasStart = gasleft();
    console.log("Gas start:", gasStart);
    uint slope = 3000000000000000;
    uint circulation = 0;
    uint purchaseToken = 500;
    uint basePrice = 100000000000000000;
    uint fee = 300000000000000;
    uint cost = curve.costOfPurchasingToken(slope, circulation, purchaseToken, basePrice,fee);
    console.log("Cost of purchasing token is:", cost);
    console.log("Gas used:", gasStart - gasleft());
}

function testCostOfSellingToken() public {
    uint slope = 0.003 * 1e18;
    uint circulation = 500;
    uint sellToken = 500;
    uint basePrice = 0.1 * 1e18;
    uint fee = 0.0003 * 1e18;
    uint cost = curve.costOfSellingToken(slope, circulation, sellToken, basePrice,fee);
    console.log("Cost of selling token is:", cost);
}
}

/*60ba8060093d393df35f3560e01c80639ead18c814610026578063709cb5bb1461003857806397da270014610078575b60043560243502604435015f5260205ff35b60043560243560443502025f52604435806001030260043502600204602052606435604435026040525f5160205101604051016084350160605260206060f35b60043560243560443502025f52604435806001030260043502600204602052606435604435026040525f516020510360405101608435900360605260206060f300*/

//0xfC47d03bd4C8a7E62A62f29000ceBa4D84142343

//cast send --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --create 60c08060093d393df35f3560e01c80639ead18c814610026578063709cb5bb1461003857806397da27001461007c575b60043560243502604435015f5260205ff35b60043560243560443502025f5260443560019003604435026004350260029004602052606435604435026040525f5160205101604051016084350160605260206060f35b60043560243560443502025f5260443580600101026004350260029004602052606435604435026040525f51602051900360405101608435900360605260206060f300


//0xfC47d03bd4C8a7E62A62f29000ceBa4D84142343