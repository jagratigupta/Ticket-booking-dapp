// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./TicketERC721.sol";

contract EventBooking {
    // Struct to hold event details
    TicketERC721 ticketERC721;
    address payable theatreOwner;
    uint256 normalSeating = 50;
    uint256 executiveSeating = 30;
    uint256 premiumSeating = 20;
    uint256 advancePayment = 1000000000000000;

    enum SeatType {
        NORMAL,
        EXECUTIVE,
        PREMIUM
    }

    struct Event {
        string eventName;
        uint256 startTime;
        uint256 endTime;
        uint256 normalSeatsBooked;
        uint256 executiveSeatsBooked;
        uint256 premiumSeatsBooked;
        bool canceled;
        address artist;
    }

    struct Ticket {
        address buyer;
        bool attended;
        SeatType seatType;
    }

    // Event ID to event mapping
    mapping(uint256 => Event) public events;

    mapping(uint256 => mapping(SeatType => uint256)) public eventTicketPrice;

    // Event ID to mapping of seat ID to buyer address
    mapping(uint256 => mapping(uint256 => Ticket)) public seatBuyers;

    // Mapping of ticket IDs to events
    // mapping(uint256 => uint256) public ticketEvent;

    // Counter for assigning new event IDs
    uint256 public eventCount = 0;

    // Modifier to check if an event is canceled
    modifier onlyActiveEvent(uint256 _eventId) {
        require(!events[_eventId].canceled, "Event is canceled");
        require(
            block.timestamp < events[_eventId].startTime,
            "Event has already occured"
        );
        _;
    }

    // Modifier to check if the caller is the artist for the event
    modifier onlyEventArtist(uint256 _eventId) {
        console.log(
            "msg sender: %s , artist: %s ",
            msg.sender,
            events[_eventId].artist,
            _eventId
        );
        // require(
        //     events[_eventId].artist == msg.sender,
        //     "Caller is not event artist"
        // );
        _;
    }

    event TicketReserved(address _from, uint256 _eventId, uint256 _ticketId);
    event TicketTransferred(
        address _from,
        address _to,
        uint256 _eventId,
        uint256 _ticketId
    );

    event AttendanceMarked(address _buyer, uint256 _eventId, uint256 _ticketId);

    constructor() {
        theatreOwner = payable(msg.sender);
    }

    // Method to create a new event
    function createEvent(
        string memory _eventName,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _normalSeatPrice,
        uint256 _executiveSeatPrice,
        uint256 _premiumSeatPrice
    ) external payable {
        console.log(
            "msg value: %n , advancePayment: %n ",
            msg.value,
            advancePayment
        );
        require(
            msg.value == advancePayment,
            "Invalid advance payment amount is 0.001 ETH"
        );
        require(_normalSeatPrice > 0, "Seat price must be greater than 0");
        require(
            _executiveSeatPrice > _normalSeatPrice,
            "Executive Seat price must be greater than Normal Seat price"
        );
        require(
            _premiumSeatPrice > _executiveSeatPrice,
            "Premium Seat price must be greater than Executive Seat price"
        );

        require(
            _startTime > block.timestamp,
            "Start time must be in the future"
        );
        require(
            _endTime > _startTime,
            "End time must be greater than Start time"
        );

        eventCount++;

        events[eventCount] = Event({
            eventName: _eventName,
            startTime: _startTime,
            endTime: _endTime,
            normalSeatsBooked: 0,
            executiveSeatsBooked: 0,
            premiumSeatsBooked: 0,
            canceled: false,
            artist: msg.sender
        });

        this.setTicketPrice(eventCount, SeatType.NORMAL, _normalSeatPrice);
        this.setTicketPrice(
            eventCount,
            SeatType.EXECUTIVE,
            _executiveSeatPrice
        );
        this.setTicketPrice(eventCount, SeatType.PREMIUM, _premiumSeatPrice);
        // theatreOwner.transfer(msg.value);
        // ticketERC721.safeMint(msg.sender, eventCount);
    }

    function setTicketPrice(
        uint256 _eventId,
        SeatType _seatType,
        uint256 _price
    ) external onlyEventArtist(_eventId) {
        eventTicketPrice[_eventId][_seatType] = _price;
    }

    // Method to cancel an event
    function cancelEvent(uint256 _eventId)
        external
        onlyEventArtist(_eventId)
        onlyActiveEvent(_eventId)
    {
        events[_eventId].canceled = true;
        uint256 timeUntilEvent = calculateTimeUntilEvent(_eventId);

        // Determine the cancellation charge based on the time until the event
        uint256 cancellationCharge;
        if (timeUntilEvent >= 7 days) {
            cancellationCharge = (advancePayment * 10) / 100; // 10% cancellation charge
        } else if (timeUntilEvent >= 3 days) {
            cancellationCharge = (advancePayment * 25) / 100; // 25% cancellation charge
        } else if (timeUntilEvent >= 1 days) {
            cancellationCharge = (advancePayment * 50) / 100; // 50% cancellation charge
        } else {
            cancellationCharge = advancePayment; // No refund, full cancellation charge
        }

        // Calculate the remaining advance that can be refunded
        // uint256 refundAmount = advancePayment - cancellationCharge;

        // address payable artist = payable(events[_eventId].artist);
        // artist.transfer(refundAmount);
    }

    function calculateTimeUntilEvent(uint256 _eventId)
        internal
        view
        returns (uint256)
    {
        // Example implementation:
        uint256 eventTime = events[_eventId].startTime; // Get the event start time
        uint256 currentTime = block.timestamp;
        if (eventTime > currentTime) {
            uint256 timeUntilEvent = eventTime - currentTime;
            return timeUntilEvent / 1 days; // Convert to days
        } else {
            return 0;
        }
    }

    function bookTicket(uint256 _eventId, uint256 _ticketId)
        external
        payable
        onlyActiveEvent(_eventId)
    {
        require(_ticketId <= 100, "Invalid _ticketId");
        uint256 seatingCapacity;
        uint256 seatsBooked;
        SeatType seatType;

        if (_ticketId >= 1 && _ticketId <= 50) {
            seatingCapacity = normalSeating;
            seatsBooked = events[_eventId].normalSeatsBooked;
            seatType = SeatType.NORMAL;
        } else if (_ticketId >= 51 && _ticketId <= 80) {
            seatingCapacity = executiveSeating;
            seatsBooked = events[_eventId].executiveSeatsBooked;
            seatType = SeatType.EXECUTIVE;
        } else {
            seatingCapacity = premiumSeating;
            seatsBooked = events[_eventId].premiumSeatsBooked;
            seatType = SeatType.PREMIUM;
        }

        console.log("Seats Booked: ", seatsBooked);
        console.log("Seating Capacity: ", seatingCapacity);

        require(seatsBooked < seatingCapacity, "All Seats are booked");

        console.log("Seat Buyer: ", seatBuyers[_eventId][_ticketId].buyer);
        console.log("Seat already bought?: ", address(0));
        require(
            seatBuyers[_eventId][_ticketId].buyer == address(0),
            "Seat already booked"
        );

        console.log("Seat booking Value passed: ", msg.value);
        console.log("Ticket Price: ", eventTicketPrice[_eventId][seatType]);
        require(
            msg.value == eventTicketPrice[_eventId][seatType],
            "Invalid payment amount"
        );

        // Transfer Ether to the theatre owner
        // theatreOwner.transfer(msg.value);

        // Mint an NFT as a ticket for the seat
        // ticketERC721.safeMint(msg.sender, _ticketId);

        seatBuyers[_eventId][_ticketId].buyer = msg.sender;
        seatBuyers[_eventId][_ticketId].seatType = seatType;

        // Update the seatsBooked count for the event
        if (seatType == SeatType.NORMAL) events[_eventId].normalSeatsBooked++;
        else if (seatType == SeatType.EXECUTIVE)
            events[_eventId].executiveSeatsBooked++;
        else events[_eventId].premiumSeatsBooked++;

        emit TicketReserved(msg.sender, _eventId, _ticketId);
    }

    // Method to transfer a ticket to another user
    function transferTicket(
        uint256 _eventId,
        uint256 _ticketId,
        address payable _to,
        uint256 amount
    ) external payable {
        console.log("Seat Owner: ", ticketERC721.ownerOf(_ticketId));
        console.log("msg.sender: ", msg.sender);
        require(
            ticketERC721.ownerOf(_ticketId) == msg.sender,
            "Caller is not the owner of the ticket"
        );

        console.log("Transferring to: ", _to);
        require(
            ticketERC721.ownerOf(_ticketId) != _to,
            "Cannot transfer ticket to self"
        );

        require(
            !events[_eventId].canceled,
            "Cannot transfer ticket for a canceled event"
        );

        SeatType seatType = seatBuyers[_eventId][_ticketId].seatType;

        console.log("Amount: ", amount);
        console.log("Ticket price: ", eventTicketPrice[_eventId][seatType]);
        require(
            amount <= eventTicketPrice[_eventId][seatType],
            "Ticket cannot be sold at a higher price, please enter a valid amount"
        );

        // Transfer the specified amount from _to to msg.sender
        (bool success, ) = _to.call{value: amount}("");
        require(success, "Transfer failed");

        // Transfer the ticket NFT from msg.sender to _to
        ticketERC721.safeTransferFrom(msg.sender, _to, _ticketId);

        seatBuyers[_eventId][_ticketId].buyer = _to;
        emit TicketTransferred(msg.sender, _to, _eventId, _ticketId);

        seatBuyers[_eventId][_ticketId].buyer = _to;
        emit TicketTransferred(msg.sender, _to, _eventId, _ticketId);
    }

    // Method to mark attendance for a ticket on the day of the event
    function markAttendance(uint256 _eventId, uint256 _ticketId) external {
        require(
            ticketERC721.ownerOf(_ticketId) == msg.sender,
            "Caller is not the owner of the ticket"
        );

        require(
            !events[_eventId].canceled,
            "Cannot mark attendance for a canceled event"
        );

        // Burn the ticket NFT to mark attendance
        // ticketERC721._burn(_ticketId);

        seatBuyers[_eventId][_ticketId].attended = true;
        emit AttendanceMarked(msg.sender, _eventId, _ticketId);
    }
}

// Resolve the only event Artist function call when called internally, msg.sender address changes to contract address
