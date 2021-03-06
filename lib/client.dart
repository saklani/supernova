import 'dart:async';

import 'package:json_rpc_2/json_rpc_2.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'core/block.dart';
import 'core/transaction.dart';
import 'enum/block_tag.dart';

/// Class for sending requests over an HTTP JSON-RPC API endpoint to Ethereum
/// clients. This library won't use the accounts feature of clients to use them
/// to create transactions, you will instead have to obtain private keys of
/// accounts yourself.
class Web3Client {
  /// Starts a client that connects to a JSON rpc API at [url].

  Web3Client(String url, {bool debug = false}) {
    final socket = WebSocketChannel.connect(Uri.parse(url));
    _client = Client(socket.cast());
    unawaited(_client.listen());
    _debug = debug;
  }

  Web3Client.from(Client client, {bool debug = true}) {
    _client = client;
    unawaited(_client.listen());
    _debug = debug;
  }

  late Client _client;
  late bool _debug;

  Future<T> _makeRPCCall<T>(String function, [List<dynamic>? params]) async {
    try {
      return await _client.sendRequest(function, params) as T;
    } on RpcException catch (error) {
      if (_debug) print('RPC error ${error.code}: ${error.message}');
      rethrow;
    }
  }

  /// Returns the current Ethereum protocol version
  Future<int> protocolVersion() {
    return _makeRPCCall<String>('eth_protocolVersion').then(int.parse);
  }

  Future<BigInt> gasPrice() {
    return _makeRPCCall<String>('eth_gasPrice').then(BigInt.parse);
  }

  /// Returns the number of the most recent block on the chain.
  Future<BigInt> blockNumber() {
    return _makeRPCCall<String>('eth_blockNumber').then(BigInt.parse);
  }

  Future<BigInt> getBalance(
    String address, {
    BigInt? blockNumber,
    BlockTag blockTag = BlockTag.latest,
  }) {
    return _makeRPCCall<String>(
      'eth_getBalance',
      [address, blockNumber ?? blockTag.name],
    ).then(BigInt.parse);
  }

  Future<BigInt> getTransactionCount(
    String address, {
    BigInt? blockNumber,
    BlockTag blockTag = BlockTag.latest,
  }) {
    return _makeRPCCall<String>(
      "eth_getTransactionCount",
      [address, blockNumber ?? blockTag.name],
    ).then(BigInt.parse);
  }

  /// Returns the EIP-191 signature over the provided data
  Future<String> sign(String address, String message) {
    return _makeRPCCall<String>('eth_sign', [address, message]);
  }

  Future<String> sendTransaction(Transaction transaction) {
    return _makeRPCCall<String>('eth_sendTransaction', [transaction.to0xMap()]);
  }

  Future<String> sendRawTransaction(String data) {
    return _makeRPCCall<String>('eth_sendRawTransaction', [data]);
  }

  Future<String> call(Transaction transaction) {
    return _makeRPCCall<String>('eth_call', [transaction.to0xMap()]);
  }

  /// Generates and return an estimate of how much gas is necessary to allow
  /// the transaction to complete
  Future<BigInt> estimateGas(Transaction transaction) {
    return _makeRPCCall<String>(
      'eth_estimateGas',
      [transaction.to0xMap()],
    ).then(BigInt.parse);
  }

  Future<Block> getBlockByHash(String hash) {
    // TODO: Add support for hydrated transactions
    return _makeRPCCall<Map<String, dynamic>>(
      'eth_getBlockByHash',
      [hash, false],
    ).then((json) => Block.fromJson(json));
  }

  Future<Block> getBlockByNumber(BigInt number) {
    // TODO: Add support for hydrated transactions
    return _makeRPCCall<Map<String, dynamic>>(
      'eth_getBlockByNumber',
      [number.toRadixString(16), false],
    ).then((json) => Block.fromJson(json));
  }

  /// Returns the chain ID of the current network
  Future<int> chainId() {
    return _makeRPCCall<String>('eth_chainId').then(int.parse);
  }
}
