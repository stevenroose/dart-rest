library rest;

import 'dart:io' show HttpStatus, HttpRequest;
import 'dart:async' show Future, getFuture;

part 'src/router.dart';


/**
 * A REST server.
 */
abstract class Rest {

  /**
   *  Resolves a REST request.
   */
  RestResponse resolve(request);
}

/**
 * A REST route using available methods.
 */
abstract class RestRoute {

  /// map of verbs and verb handlers
  Map<String,Verb> verbs;

  /**
   * Gets a verb from current verbs given a method name.
   */
  RestResponse verb(method) {
    if(!verbs.containsKey(method))
      throw new NoSuchVerbException(method);
    return verbs[method]();
  }

  /**
   * Provides a response, given an REST request.
   */
  RestResponse call(request);
}

/**
 * A response to a REST request.
 */
abstract class RestResponse {
  /**
   * Generates a REST response.
   */
  void build(dynamic response);
}

/**
 * A REST verb handler for a request route.
 */
abstract class Verb {

  /// Response handler for this verb.
  final Function callback;

  /// Constructor that produces the verb action.
  Verb(callback) {
    this.callback = callback is Function ?
      callback : () { return callback; };
  }

  /**
   * Calls the response handler.
   */
  String call() => this.callback();
}

/**
 * Exception when defining verb mappings for nonexistent methods.
 */
class NoSuchVerbException implements Exception {
  final String msg;
  const NoSuchVerbException ([this.msg]);
  String toString() => "No such method ${msg}";
}
