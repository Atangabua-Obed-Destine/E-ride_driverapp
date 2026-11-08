import 'dart:convert';
import 'package:ride_sharing_user_app/helper/deposit_helper.dart';
import 'package:ride_sharing_user_app/helper/ride_request_ringer.dart';
import 'package:ride_sharing_user_app/helper/trip_event_gate.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/ride/widgets/move_widgets.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/home/screens/ride_list_screen.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/map/screens/map_screen.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/screens/ride_request_list_screen.dart';
import 'package:ride_sharing_user_app/features/safety_setup/controllers/safety_alert_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/splash_controller.dart';
import 'package:ride_sharing_user_app/features/trip/screens/payment_received_screen.dart';
import 'package:ride_sharing_user_app/features/trip/screens/review_this_customer_screen.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import '../features/dashboard/screens/dashboard_screen.dart';


class PusherHelper{

  static PusherChannelsClient?  pusherClient;

  /// Every channel this app follows, oldest first. The library does not restore
  /// subscriptions after a reconnect, so they are subscribed again from here. A
  /// shift sees many requests, each with its own channels: only the latest are kept.
  static final Map<String, PrivateChannel> _channels = {};
  static const int _maxChannels = 40;

  static void initializePusher() async{
    // One socket per login (logout closes it in pusherDisconnectPusher).
    if (pusherClient != null) return;
    PusherChannelsOptions testOptions = PusherChannelsOptions.fromHost(
      host: Get.find<SplashController>().config!.webSocketUrl ?? '',
      scheme: Get.find<SplashController>().config!.websocketScheme == 'https' ? 'wss' : 'ws',
      key: Get.find<SplashController>().config!.webSocketKey ?? '',
      port: int.parse(Get.find<SplashController>().config?.webSocketPort ?? '6001'),
    );
    final PusherChannelsClient client = PusherChannelsClient.websocket(
      options: testOptions,
      connectionErrorHandler: (exception, trace, refresh) async {
        Get.find<SplashController>().setPusherStatus('Disconnected');
        refresh();
      },
    );
    pusherClient = client;

    // Every lifecycle event used to set "Disconnected", even a successful connection.
    client.lifecycleStream.listen((state) {
      Get.find<SplashController>().setPusherStatus(
        state == PusherChannelsClientLifeCycleState.establishedConnection ? 'Connected' : 'Disconnected',
      );
    });
    client.onConnectionEstablished.listen((_) {
      for (final PrivateChannel channel in _channels.values) {
        channel.subscribeIfNotUnsubscribed();
      }
    });

    await client.connect();
  }

  /// The channel, created and subscribed once. Null when it is already followed,
  /// so that its events are bound only once. Channels used to be skipped entirely
  /// when the socket had not connected yet (a request subscribed one second after
  /// start-up could be missed).
  PrivateChannel? _follow(String name) {
    final PusherChannelsClient? client = pusherClient;
    if (client == null || _channels.containsKey(name)) return null;
    if (_channels.length >= _maxChannels) {
      _channels.remove(_channels.keys.first)?.unsubscribe();
    }
    final PrivateChannel channel = client.privateChannel(name, authorizationDelegate:
      EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
        authorizationEndpoint: Uri.parse('${Get.find<SplashController>().config!.websocketScheme == 'https' ? 'https' : 'http'}://${Get.find<SplashController>().config!.webSocketUrl}/broadcasting/auth'),
        headers:  {
          "Accept": "application/json",
          "Authorization": "Bearer ${Get.find<AuthController>().getUserToken()}",
        },
      ));
    _channels[name] = channel;
    // Not connected yet: onConnectionEstablished subscribes it.
    if (client.socketId != null) channel.subscribe();
    return channel;
  }


  void driverTripRequestSubscribe(String id){
    final PrivateChannel? channel = _follow("private-customer-trip-request.$id");
    if (channel == null) return;
    channel.bind("customer-trip-request.$id").listen((event) {
      // Follow the request's cancel and "taken" events even when its push came first.
      customerInitialTripCancel(jsonDecode(event.data!)['trip_id'], id);
      anotherDriverAcceptedTrip(jsonDecode(event.data!)['trip_id'], id);
      if (!TripEventGate.firstTime(jsonDecode(event.data!)['trip_id']?.toString(), TripEventGate.request)) return;
      Get.find<RideController>().ongoingTripList().then((value){
        if((Get.find<RideController>().ongoingTrip ?? []).isEmpty){
          RideRequestRinger.startInAppRing(rideRequestId: jsonDecode(event.data!)['trip_id']);
          Get.find<RideController>().getPendingRideRequestList(1);
          Get.find<RideController>().setRideId(jsonDecode(event.data!)['trip_id']);
          Get.find<RideController>().getRideDetailBeforeAccept(jsonDecode(event.data!)['trip_id']).then((value){
            if(value.statusCode == 200){
              Get.find<RiderMapController>().getPickupToDestinationPolyline();
              Get.find<RiderMapController>().setRideCurrentState(RideState.pending);
              Get.find<RideController>().updateRoute(false, notify: true);
              Get.to(()=> const MapScreen());
            }
          });

        }else{
          if(Get.currentRoute == '/MapScreen'){
            Get.find<RideController>().getPendingRideRequestList(1,limit: 100);
          }else{
            Get.to(()=> RideRequestScreen());
          }

        }
      });
    });
  }

  void customerInitialTripCancel(String tripId, String userId){
    final PrivateChannel? channel = _follow("private-customer-trip-cancelled.$tripId.$userId");
    if (channel == null) return;
    channel.bind("customer-trip-cancelled.$tripId.$userId").listen((event) {
      if (!TripEventGate.firstTime(jsonDecode(event.data!)['trip_id']?.toString(), TripEventGate.cancelled)) return;
      RideRequestRinger.stopInAppRing(rideRequestId: jsonDecode(event.data!)['trip_id']);
      if(Get.find<RideController>().tripDetail?.id == jsonDecode(event.data!)['trip_id']){
        Get.find<SafetyAlertController>().cancelDriverNeedSafetyStream();
        Get.find<RideController>().getPendingRideRequestList(1).then((value) {
          if (value.statusCode == 200) {
            Get.find<RiderMapController>().setRideCurrentState(RideState.initial);
            Get.offAll(() => const DashboardScreen());
          }
        });
      }else{
        Get.find<RideController>().ongoingTripList();
        Get.find<RideController>().getPendingRideRequestList(1,limit: 100);
      }

    });
  }

  void anotherDriverAcceptedTrip(String tripId, String userId){
    final PrivateChannel? channel = _follow("private-another-driver-trip-accepted.$tripId.$userId");
    if (channel == null) return;
    channel.bind("another-driver-trip-accepted.$tripId.$userId").listen((event) {
      if (!TripEventGate.firstTime(jsonDecode(event.data!)['trip_id']?.toString(), TripEventGate.taken)) return;
      RideRequestRinger.stopInAppRing(rideRequestId: jsonDecode(event.data!)['trip_id']);
      if(Get.find<RideController>().tripDetail?.id == jsonDecode(event.data!)['trip_id']){
        Get.find<SafetyAlertController>().cancelDriverNeedSafetyStream();
        Get.find<RideController>().getPendingRideRequestList(1).then((value) {
          if (value.statusCode == 200) {
            Get.find<RiderMapController>().setRideCurrentState(RideState.initial);
            Get.offAll(() => const DashboardScreen());
          }
        });
      }else{
        Get.find<RideController>().ongoingTripList();
        Get.find<RideController>().getPendingRideRequestList(1,limit: 100);
      }
    });
  }

  void tripCancelAfterOngoing(String tripId){
    final PrivateChannel? channel = _follow("private-customer-trip-cancelled-after-ongoing.$tripId");
    if (channel == null) return;
    channel.bind("customer-trip-cancelled-after-ongoing.$tripId").listen((event) {
      Get.find<SafetyAlertController>().cancelDriverNeedSafetyStream();
      Get.find<RideController>().getRideDetails(jsonDecode(event.data!)['id']).then((value){
        if(value.statusCode == 200){
          if(Get.find<RideController>().tripDetail?.type == AppConstants.parcel){
            Get.offAll(() => const DashboardScreen());
          }else if(Get.find<RideController>().tripDetail?.isMove ?? false){
            // The customer ended the move: it is paid in person.
            finishCompletedMove(jsonDecode(event.data!)['id'], reviewed: Get.find<RideController>().tripDetail?.isReviewed ?? false);
          }else{
            Get.find<RideController>().getFinalFare(jsonDecode(event.data!)['id']).then((value){
              if(value.statusCode == 200){
                Get.find<RiderMapController>().setRideCurrentState(RideState.initial);
                Get.to(()=> const PaymentReceivedScreen());
              }
            });
          }
        }
      });
    });
  }

  /// The customer paid the booking deposit: the driver can set off.
  void customerDepositPaid(String tripId){
    final PrivateChannel? channel = _follow("private-customer-deposit-paid.$tripId");
    if (channel == null) return;
    channel.bind("customer-deposit-paid.$tripId").listen((event) {
      // DepositHelper announces a trip's deposit once, whichever path brings it.
      DepositHelper.onDepositPaid(jsonDecode(event.data!)['id']);
    });
  }

  void tripPaymentSuccessful(String tripId){
    final PrivateChannel? channel = _follow("private-customer-trip-payment-successful.$tripId");
    if (channel == null) return;
    channel.bind("customer-trip-payment-successful.$tripId").listen((event) {
      if (!TripEventGate.firstTime(jsonDecode(event.data!)['id']?.toString(), TripEventGate.paid)) return;
      if(jsonDecode(event.data!)['type'] == 'parcel'){
        Get.find<RideController>().getRideDetails(jsonDecode(event.data!)['id']).then((value){
          if(value.statusCode == 200){
            Get.find<RideController>().getOngoingParcelList();
            Get.back();
          }
        });
      }else{

        Get.find<RideController>().ongoingTripList().then((value){
          if((Get.find<RideController>().ongoingTrip ?? []).isEmpty){
            Get.find<RideController>().getRideDetails(jsonDecode(event.data!)['id']).then((value){
              if(value.statusCode == 200){
                if(Get.find<SplashController>().config!.reviewStatus!){
                  Get.offAll(()=>  ReviewThisCustomerScreen(tripId: jsonDecode(event.data!)['id']));
                }else{
                  Get.offAll(()=> const DashboardScreen());
                }
              }
            });
          }else{
            Get.offAll(()=> const RideListScreen());
          }
        });

      }

    });
  }


  /// Logout: the socket is closed for good, so the next login starts clean.
  void pusherDisconnectPusher(){
    pusherClient?.dispose();
    pusherClient = null;
    _channels.clear();
    Get.find<SplashController>().setPusherStatus('Disconnected');
  }


}
