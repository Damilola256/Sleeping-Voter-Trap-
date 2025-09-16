// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IResponse {
    function respond(bytes calldata data) external;
}
