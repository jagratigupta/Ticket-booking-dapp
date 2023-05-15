import React, { useEffect, useState } from "react";
import { ethers } from "ethers";
import "./App.css";
import EventFactoryContract from "./contracts/EventFactory.json";
import EventContract from "./contracts/Event.json";

const provider = new ethers.providers.Web3Provider(window.ethereum);
const signer = provider.getSigner();

const eventFactoryAddress = "..."; // Address of the deployed EventFactory contract
const eventTokenAddress = "..."; // Address of the deployed EventToken contract

const App = () => {
  const [eventFactory, setEventFactory] = useState(null);
  const [events, setEvents] = useState([]);
  const [selectedEvent, setSelectedEvent] = useState(null);
  const [ticketPrice, setTicketPrice] = useState(0);
  const [seatingCapacity, setSeatingCapacity] = useState(0);
  const [cancellationCharge, setCancellationCharge] = useState(0);
  const [tickets, setTickets] = useState([]);
  const [ticketCount, setTicketCount] = useState(0);

  const connectWallet = async () => {
    try {
      await window.ethereum.request({ method: "eth_requestAccounts" });
    } catch (error) {
      console.error(error);
    }
  };

  const loadEvents = async () => {
    const factoryContract = new ethers.Contract(
      eventFactoryAddress,
      EventFactoryContract.abi,
      provider
    );
    setEventFactory(factoryContract);

    const artist = await signer.getAddress();
    const artistEvents = await factoryContract.getArtistEvents(artist);

    const eventContracts = artistEvents.map(
      (address) => new ethers.Contract(address, EventContract.abi, provider)
    );

    const eventsData = await Promise.all(
      eventContracts.map(async (contract) => {
        const eventData = await contract.getEventData();
        return { contract, ...eventData };
      })
    );

    setEvents(eventsData);
  };

  const createEvent = async () => {
    const factoryContract = eventFactory.connect(signer);
    await factoryContract.createEvent(
      artist,
      eventName,
      ticketPrice,
      seatingCapacity,
      cancellationCharge,
      eventTokenAddress
    );
    await loadEvents();
  };

  const selectEvent = async (event) => {
    setSelectedEvent(event);

    const ticketCount = await event.contract.totalTicketsSold();
    setTicketCount(ticketCount.toNumber());

    const ticketsData = [];
    for (let i = 0; i < ticketCount; i++) {
      const ticket = await event.contract.tickets(i);
      ticketsData.push(ticket);
    }
    setTickets(ticketsData);
  };

  const purchaseTicket = async () => {
    const eventContract = selectedEvent.contract.connect(signer);
    const ticketPriceWei = ethers.utils.parseEther(ticketPrice.toString());
    await eventContract.reserveTicket({ value: ticketPriceWei });
    await selectEvent(selectedEvent);
  };

  useEffect(() => {
    if (window.ethereum) {
      connectWallet();
    }
  }, []);

  return (
    <div className="app">
      <h1 className="title">Event Booking Application</h1>
      <div className="event-list">
        <h2 className="section-title">My Events</h2>
        {events.map((event) => (
          <div key={event.contract.address} className="event-item">
            <p className="event-name">{event.eventName}</p>
            <button
              className="view-tickets-btn"
              onClick={() => selectEvent(event)}
            >
              View Tickets
            </button>
          </div>
        ))}
      </div>

      {selectedEvent && (
        <div className="selected-event">
          <h3 className="event-name">{selectedEvent.eventName}</h3>
          <p className="event-details">
            Ticket Price: {selectedEvent.ticketPrice}
          </p>
          <p className="event-details">
            Seating Capacity: {selectedEvent.seatingCapacity}
          </p>
          <p className="event-details">
            Cancellation Charge: {selectedEvent.cancellationCharge}
          </p>
          <h4 className="section-title">Tickets ({ticketCount} sold)</h4>
          {tickets.map((ticket) => (
            <p key={ticket.tokenId} className="ticket">
              Ticket ID: {ticket.tokenId} | Owner: {ticket.buyer} | Attended:{" "}
              {ticket.attended ? "Yes" : "No"}
            </p>
          ))}
          <button className="purchase-ticket-btn" onClick={purchaseTicket}>
            Purchase Ticket
          </button>
        </div>
      )}

      <div className="create-event">
        <h2 className="section-title">Create Event</h2>
        <input
          type="text"
          placeholder="Event Name"
          onChange={(e) => setEventName(e.target.value)}
          className="input-field"
        />
        <input
          type="number"
          placeholder="Ticket Price"
          onChange={(e) => setTicketPrice(e.target.value)}
          className="input-field"
        />
        <input
          type="number"
          placeholder="Seating Capacity"
          onChange={(e) => setSeatingCapacity(e.target.value)}
          className="input-field"
        />
        <input
          type="number"
          placeholder="Cancellation Charge"
          onChange={(e) => setCancellationCharge(e.target.value)}
          className="input-field"
        />
        <button className="create-event-btn" onClick={createEvent}>
          Create Event
        </button>
      </div>
    </div>
  );
};

export default App;
