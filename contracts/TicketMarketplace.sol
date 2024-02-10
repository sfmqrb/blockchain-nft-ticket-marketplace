// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ITicketNFT} from "./interfaces/ITicketNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TicketNFT} from "./TicketNFT.sol";
import {ITicketMarketplace} from "./interfaces/ITicketMarketplace.sol";
import "hardhat/console.sol";


contract TicketMarketplace is ITicketMarketplace {
    address public owner;
    IERC20 public ERC20Address;
    TicketNFT public nftContract;
    uint128 public currentEventId = 0;
    uint128 public nextTicketToSell;
    uint128[] private eventIds;


    struct Event {
        uint128 maxTickets;
        uint256 pricePerTicket;
        uint256 pricePerTicketERC20;
        uint128 nextTicketToSell;
    }
    mapping(uint128 => Event) public events;

    constructor(address _erc20Address) {
        owner = msg.sender;
        ERC20Address = IERC20(_erc20Address);
        nftContract = new TicketNFT();
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized access");
        _;
    }

    function createEvent(uint128 maxTickets, uint256 pricePerTicket, uint256 pricePerTicketERC20) external override onlyOwner {
        Event memory newEvent = Event(maxTickets, pricePerTicket, pricePerTicketERC20, nextTicketToSell);
        events[currentEventId] = newEvent;
        eventIds.push(currentEventId);
        currentEventId += 1;
        emit EventCreated(nextTicketToSell, maxTickets, pricePerTicket, pricePerTicketERC20);
    }

    function setMaxTicketsForEvent(uint128 eventId, uint128 newMaxTickets) external override onlyOwner {
        require(newMaxTickets > events[eventId].maxTickets, "The new number of max tickets is too small!");
        events[eventId].maxTickets = newMaxTickets;
        emit MaxTicketsUpdate(eventId, newMaxTickets);
    }

    function setPriceForTicketETH(uint128 eventId, uint256 price) external override onlyOwner {
        events[eventId].pricePerTicket = price;
        emit PriceUpdate(eventId, price, "ETH");
    }

    function setPriceForTicketERC20(uint128 eventId, uint256 price) external override onlyOwner {
        events[eventId].pricePerTicketERC20 = price;
        emit PriceUpdate(eventId, price, "ERC20");
    }


    function buyTickets(uint128 eventId, uint128 ticketCount) payable external override {
        uint256 totalPrice;
        try this.calculateTotalPrice(events[eventId].pricePerTicket, ticketCount) returns (uint256 result) {
            totalPrice = result;
        } catch {
            revert("Overflow happened while calculating the total price of tickets. Try buying smaller number of tickets.");
        }
        require(msg.value >= events[eventId].pricePerTicket * ticketCount, "Not enough funds supplied to buy the specified number of tickets.");
        
        uint128 availableTickets = events[eventId].maxTickets - events[eventId].nextTicketToSell;
        require(ticketCount <= availableTickets, "We don't have that many tickets left to sell!");

        for (uint128 i = 0; i < ticketCount; i++) {
            uint256 nftId = (uint256(eventId) << 128) | uint256(events[eventId].nextTicketToSell + i);
            nftContract.mintFromMarketPlace(msg.sender, nftId);
        }

        events[eventId].nextTicketToSell += ticketCount;
        emit TicketsBought(eventId, ticketCount, "ETH");
    }

    function buyTicketsERC20(uint128 eventId, uint128 ticketCount) external override {
        uint256 totalPrice;
        try this.calculateTotalPrice(events[eventId].pricePerTicketERC20, ticketCount) returns (uint256 result) {
            totalPrice = result;
        } catch {
            revert("Overflow happened while calculating the total price of tickets. Try buying smaller number of tickets.");
        }
        totalPrice = events[eventId].pricePerTicketERC20 * ticketCount;

        uint128 availableTickets = events[eventId].maxTickets - events[eventId].nextTicketToSell;
        require(ticketCount <= availableTickets, "We don't have that many tickets left to sell!");
        require(ERC20Address.transferFrom(msg.sender, address(this), totalPrice), "SampleCoin token transfer failed");

        for (uint128 i = 0; i < ticketCount; i++) {
            uint256 nftId = (uint256(eventId) << 128) | uint256(events[eventId].nextTicketToSell + i);
            nftContract.mintFromMarketPlace(msg.sender, nftId);
        }

        events[eventId].nextTicketToSell += ticketCount;
        emit TicketsBought(eventId, ticketCount, "ERC20");
    }
    function setERC20Address(address newERC20Address) external override onlyOwner {
        ERC20Address = IERC20(newERC20Address);
        emit ERC20AddressUpdate(newERC20Address);
    }
    function calculateTotalPrice(uint256 ticketPrice, uint128 ticketCount) external pure returns (uint256) {
        return ticketPrice * ticketCount;
    }
}
