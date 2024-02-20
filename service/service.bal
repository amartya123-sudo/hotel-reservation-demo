import ballerina/http;

final Room[] rooms = getAllRooms();
table<Reservation> key(id) roomReservations = table [];

service /reservations on new http:Listener(9090) {

    resource function put [int reservationId](UpdateReservationRequest payload) returns Reservation|UpdateReservationError|error {
        Reservation? reservation = roomReservations[reservationId];
        if (reservation is ()) {
            return {body: "Reservation not found"};
        }
        Room? room = check getAvailableRoom(payload.checkinDate, payload.checkoutDate, reservation.room.'type.name);
        if (room is ()) {
            return {body: "No rooms available for the given dates"};
        }
        reservation.room = room;
        reservation.checkinDate = payload.checkinDate;
        reservation.checkoutDate = payload.checkoutDate;
        sendNotificationForReservation(reservation, "Updated");
        return reservation;
    }

    resource function delete [int reservationId]() returns http:NotFound|http:Ok {
        if (roomReservations.hasKey(reservationId)) {
            _ = roomReservations.remove(reservationId);
            return http:OK;
        } else {
            return http:NOT_FOUND;
        }
    }

    resource function get roomTypes(string checkinDate, string checkoutDate, int guestCapacity) returns RoomType[]|error {
        return getAvailableRoomTypes(checkinDate, checkoutDate, guestCapacity);
    }

    resource function post .(NewReservationRequest payload) returns Reservation|NewReservationError|error {
        Room|() availableRoom = check getAvailableRoom(payload.checkinDate, payload.checkoutDate,  payload.roomType);
        if(availableRoom is ()){
            return {body: "no rooms available for the given dates"};
        }
        Reservation reservation = {
            id: roomReservations.length() + 1,
            room: availableRoom,
            checkinDate: payload.checkinDate,
            checkoutDate: payload.checkoutDate,
            user: payload.user
        };
        roomReservations.add(reservation);
        sendNotificationForReservation(reservation, "Created");
        return reservation;
    }

    resource function get users/[string userId]() returns Reservation[] {
        Reservation[] reservations = from Reservation r in roomReservations
        where r.user.id == userId
        select r;
        return reservations;
    }
}

