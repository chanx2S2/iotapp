
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

List<int> mqttServerIp =[118,67,130,225];

int mqttServerPort =1883;

String mqttServerIpString()
{
  return '${mqttServerIp[0]}.${mqttServerIp[1]}.${mqttServerIp[2]}.${mqttServerIp[3]}';
}


/// The subscribed callback
void onSubscribed(String topic) {
  print('MQTT::Subscription confirmed for topic $topic');
}

/// The unsolicited disconnect callback
void onDisconnected() {
  print('MQTT::OnDisconnected client callback - Client disconnection');
  if (client.connectionStatus!.disconnectionOrigin ==
      MqttDisconnectionOrigin.solicited) {
    print('MQTT::OnDisconnected callback is solicited, this is correct');
  } else {
    print(
        'MQTT::OnDisconnected callback is unsolicited or none, this is incorrect - exiting');
    exit(-1);
  }
  if (pongCount == 3) {
    print('MQTT:: Pong count is correct');
  } else {
    print('MQTT:: Pong count is incorrect, expected 3. actual $pongCount');
  }
}

/// The successful connect callback
void onConnected() {
  print(
      'MQTT::OnConnected client callback - Client connection was successful');
}

/// Pong callback
void pong() {
  print('MQTT::Ping response client callback invoked');
  pongCount++;
}

/// A websocket URL must start with ws:// or wss:// or Dart will throw an exception, consult your websocket MQTT broker
/// for details.
/// To use websockets add the following lines -:
/// client.useWebSocket = true;
/// client.port = 80;  ( or whatever your WS port is)
/// There is also an alternate websocket implementation for specialist use, see useAlternateWebSocketImplementation
/// Note do not set the secure flag if you are using wss, the secure flags is for TCP sockets only.
/// You can also supply your own websocket protocol list or disable this feature using the websocketProtocols
//final client = MqttServerClient.withPort(mqttServerIpString(), '',mqttServerPort);
final client = MqttServerClient(mqttServerIpString(), '');
var pongCount = 0; // Pong counter


Future<void> startServiceMqtt() async {

  /// setter, read the API docs for further details here, the vast majority of brokers will support the client default
  /// list so in most cases you can ignore this.
  ///
  /// Set logging on if needed, defaults to off
  client.logging(on: true);

  /// Set the correct MQTT protocol for mosquito
  client.setProtocolV311();

  /// If you intend to use a keep alive you must set it here otherwise keep alive will be disabled.
  client.keepAlivePeriod = 1000;

  /// The connection timeout period can be set if needed, the default is 5 seconds.
  client.connectTimeoutPeriod = 5000; // milliseconds

  /// Add the unsolicited disconnection callback
  client.onDisconnected = onDisconnected;

  /// Add the successful connection callback
  client.onConnected = onConnected;

  /// Add a subscribed callback, there is also an unsubscribed callback if you need it.
  /// You can add these before connection or change them dynamically after connection if
  /// you wish. There is also an onSubscribeFail callback for failed subscriptions, these
  /// can fail either because you have tried to subscribe to an invalid topic or the broker
  /// rejects the subscribe request.
  client.onSubscribed = onSubscribed;

  client.onSubscribeFail = onSubscribed;

  /// Set a ping received callback if needed, called whenever a ping response(pong) is received
  /// from the broker.
  client.pongCallback = pong;

  /// Create a connection message to use or use the default one. The default one sets the
  /// client identifier, any supplied username/password and clean session,
  /// an example of a specific one below.
  final connMess = MqttConnectMessage()
      //.withClientIdentifier('Mqtt_MyClientUniqueId')
      .withWillTopic('willtopic') // If you set this you must set a will message
      .withWillMessage('My Will message')
      .startClean() // Non persistent session for testing
      //.authenticateAs(userId,password) // additional code when connecting to a broker w/ creds
      .withWillQos(MqttQos.atLeastOnce);

  client.connectionMessage = connMess;

  /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
  /// in some circumstances the broker will just disconnect us, see the spec about this, we however will
  /// never send malformed messages.
  try {
    await client.connect();
  } on NoConnectionException catch (e) {
    // Raised by the client when connection fails.
    print('MQTT::client exception - $e');
    client.disconnect();
  } on SocketException catch (e) {
    // Raised by the socket layer
    print('MQTT::socket exception - $e');
    client.disconnect();
  }

  /// Check we are connected
  if (client.connectionStatus!.state == MqttConnectionState.connected) {
    print('MQTT::Mosquitto client connected');
  } else {
    /// Use status here rather than state if you also want the broker return code.
    print(
        'MQTT::ERROR Mosquitto client connection failed - disconnecting, status is ${client.connectionStatus}');
    client.disconnect();
    exit(-1);
  }

  print('MQTT::Sleeping....');
  //await MqttUtilities.asyncSleep(60);

  /// Ok, we will now sleep a while, in this gap you will see ping request/response
  /// messages being exchanged by the keep alive mechanism.
}

Future<void> stopServiceMatt() async {
  /// Wait for the unsubscribe message from the broker if you wish.
  await MqttUtilities.asyncSleep(2);
  print('MQTT::Disconnecting');
  client.disconnect();
  print('MQTT::Exiting normally');
}

Subscription? subscribeMqttTpoic(String topic){
  /// Ok, lets try a subscription
  print('MQTT::Subscribing to topic');
  //const topic = 'test/lol'; // Not a wildcard topic
  //client.subscribe(topic, MqttQos.atMostOnce);
  return client.subscribe(topic, MqttQos.exactlyOnce);
}

void unSetMqttTopic(String topic){

  /// Finally, unsubscribe and exit gracefully
  print('MQTT::Unsubscribing');
  client.unsubscribe(topic);
}

void publishMessageMqtt(String pubTopic, String payload){
  /// Lets publish to our topic
  /// Use the payload builder rather than a raw buffer
  /// Our known topic to publish to
  //const pubTopic = 'test/tot';
  final builder = MqttClientPayloadBuilder();
  builder.addString(payload);

  /// Subscribe to it
  // print('MQTT::Subscribing to the Dart/Mqtt_client/testtopic topic');
  // client.subscribe(pubTopic, MqttQos.exactlyOnce);

  /// Publish it
  print('MQTT::Publishing our topic');
  client.publishMessage(pubTopic, MqttQos.exactlyOnce, builder.payload!);
  //client.publishMessage(pubTopic, MqttQos.atMostOnce, builder.payload!);
}