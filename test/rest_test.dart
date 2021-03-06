library rest_test;

import 'dart:async' show Future;
import 'dart:io' show HttpServer, HttpRequest, HttpClient;
import 'package:http/http.dart' as http;

import 'package:rest/rest.dart' as rest;
import 'package:rest/http_rest.dart';
import 'package:unittest/unittest.dart';
import 'src/rest_test_util.dart';

void main() {

  group('Router :::', () {

    var test_routes = {};
    var test_router = null;

    setUp(() {

      test_routes = {
        r'foo': RestTestUtil.returnTrue,
        r'biz': {
          r'bar': RestTestUtil.returnFalse,
        },
        r'bat': "String endpoint\r\n",
        r'fiz': {
          r'\d+_*test[abc]?': RestTestUtil.returnString
        },
        r'fud': {
          r'bap': () => RestTestUtil.returnString()+" fud/bap",
          r"bap\d+": () => RestTestUtil.returnString()+" fud/bap\d+",
        }
      };

      test_router = new Router(test_routes);
    });

    test('constructor produces instance', () {
      expect(test_router, new isInstanceOf<Router>('Router'));
    });

    test('empty routing map returns empty map', () {
      var test_router_compilation = test_router.compile({});
      expect(test_router_compilation, equals({}));
    });

    group('resolve :::', () {

      var test_router_compilation = null;
      var test_endpoint = null;

      setUp(() {
        test_router_compilation = test_router.compile(test_routes);
      });

      test('returns correct endpoint one level deep', () {
        test_endpoint = test_router.resolve('foo');
        expect(test_endpoint(), isTrue);
      });

      test('returns correct endpoint >one levels deep', () {
        test_endpoint = test_router.resolve('biz/bar');
        expect(test_endpoint(), isFalse);
      });

      test('returns correct endpoint with a complex regular expression', () {
        test_endpoint = test_router.resolve('fiz/20_test');
        expect(test_endpoint(), equals(RestTestUtil.returnString()));
        expect(() => test_router.resolve('fix/20_testa_somethingelse'),
          throwsA(new isInstanceOf<RouteNotFoundException>()));
      });

      test('returns correct endpoint given partial request match', () {
        test_endpoint = test_router.resolve('fud/bap');
        expect(test_endpoint(),
          equals(RestTestUtil.returnString()+" fud/bap"));
        test_endpoint = test_router.resolve('fud/bap2');
        expect(test_endpoint(),
          equals(RestTestUtil.returnString()+" fud/bap\d+"));
      });

      test('throws RouteNotFoundException for unrouteable URIs', () {
        test_endpoint = test_router.resolve('biz/bar');
        expect(() => test_router.resolve('biz'),
          throwsA(new isInstanceOf<RouteNotFoundException>()));
        expect(() => test_router.resolve('biz/bar/20'),
          throwsA(new isInstanceOf<RouteNotFoundException>()));
      });
    });
  });

  group('HTTP Rest :::', () {

    var _test_addr = '127.0.0.1';
    var _test_port = 33133;

    var test_routes = {};
    var test_rest = null;
    var test_server = null;
    var test_client = null;

    setUp(() {

      // server setup

      test_routes = {
        r'^foo': HttpRest.OK,
        r'^bar': new HttpRestRoute({
          'GET': HttpRest.CREATED,
          'POST': () => new HttpRestResponse().build(201, "called bar!\r\n"),
          'PUT': () => { 'code': 201, 'body': "called bar!\r\n" },
          'DELETE': () => "called bar!\r\n",
        }),
        r'^bat': {
          r'^bar': {
            null: new HttpRestRoute({
              'GET': HttpRest.CREATED,
            }),
            r'\d+': () => { 'code': 201, 'body': "requested a bat!\r\n" },
          }
        }
      };

      test_rest = new HttpRest(test_routes);

      test_client = new http.Client();

      return HttpServer.bind(_test_addr, _test_port).then((server) {
        test_server = server;
        server.listen((HttpRequest request) {
          try {
            test_rest.resolve(request);
          } on RouteNotFoundException {
            request.response
              ..statusCode = 404
              ..close();
          }
        });
      });
    });

    tearDown(() {
      return test_server.close();
    });

    test('using HttpRest status constant 200', () {
      test_client.get("http://${_test_addr}:${_test_port}/foo")
        .then(expectAsync((response) {
          expect(response.statusCode, equals(200));
        }));
    });

    test('using a verb map', () {
      test_client
        ..get("http://${_test_addr}:${_test_port}/bar")
          .then(expectAsync((response) {
            expect(response.statusCode, equals(201));
          }))
        ..post("http://${_test_addr}:${_test_port}/bar")
          .then(expectAsync((response) {
            expect(response.statusCode, equals(201));
            expect(response.body, equals("called bar!\r\n"));
          }))
        ..put("http://${_test_addr}:${_test_port}/bar")
          .then(expectAsync((response) {
            expect(response.statusCode, equals(201));
            expect(response.body, equals("called bar!\r\n"));
          }))
        ..delete("http://${_test_addr}:${_test_port}/bar")
          .then(expectAsync((response) {
            expect(response.statusCode, equals(200));
            expect(response.body, equals("called bar!\r\n"));
          }));
    });

    test('using a nested and null route', () {
      test_client
        ..get("http://${_test_addr}:${_test_port}/bat")
          .then(expectAsync((response) {
            expect(response.statusCode, equals(404));
          }))
        ..get("http://${_test_addr}:${_test_port}/bat/bar")
          .then(expectAsync((response) {
            expect(response.statusCode, equals(201));
          }))
        ..get("http://${_test_addr}:${_test_port}/bat/bar/20")
          .then(expectAsync((response) {
            expect(response.statusCode, equals(201));
            expect(response.body, equals("requested a bat!\r\n"));
          }));
    });

    test('requesting an undefined verb gives 405', () {
      test_client.head("http://${_test_addr}:${_test_port}/bar")
        .then(expectAsync((response) {
          expect(response.statusCode, equals(405));
        }));
    });
  });
}
