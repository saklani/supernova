import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:convert/convert.dart';
import 'package:flutter/cupertino.dart';
import 'package:nova/nova.dart';
import 'package:pointycastle/export.dart';
import 'package:rlp/rlp.dart';

import 'core.dart';
import 'utils.dart';

class Wallet extends Account {
  /// 1. Sign a transaction using the private key
  /// 2. Sign and send a transaction using the private key
  final String privateKey;

  Wallet(
    this.privateKey,
    String url,
  ) : super(
          _getAddress(BigInt.parse(privateKey)),
          Web3Client(url),
        );

  Future<SignedTransaction> signTransaction(Transaction transaction) async {
    final hash = encode(transaction);
    final parameters = ECCurve_secp256k1();
    final ecdsa = ECDSASigner(null, HMac(SHA256Digest(), 64));
    final key = ECPrivateKey(
      BigInt.parse(privateKey),
      parameters,
    );
    ecdsa.init(true, PrivateKeyParameter(key));
    final signature = ecdsa.generateSignature(hash) as ECSignature;

    // Public key to sign the transaction.
    BigInt publicKey = _getPublicKey(BigInt.parse(privateKey), parameters);

    // Recovery ID v is 0 or 1 depending on whether R or R' is used as the
    int v = -1;
    for (int i = 0; i < 4; i++) {
      BigInt? k = _recoverFromSignature(
        i,
        signature.r,
        signature.s,
        hash,
        parameters,
      );
      if (k != null && k == publicKey) {
        v = i + 2 * transaction.chainId + 35;
        break;
      }
    }

    final rawTransaction = Rlp.encode([
      transaction.nonce,
      transaction.gasPrice,
      transaction.gasLimit,
      transaction.to,
      transaction.value,
      transaction.input.isEmpty ? 0 : transaction.input,
      v,
      signature.r,
      signature.s,
    ].map((e) => BigInt.parse(e.toString())).toList());

    return SignedTransaction(
      nonce: transaction.nonce,
      gasPrice: transaction.gasPrice,
      gasLimit: transaction.gasLimit,
      to: transaction.to,
      value: transaction.value,
      input: transaction.input,
      messageHash: '0x${hex.encode(hash)}',
      v: v,
      r: signature.r,
      s: signature.s,
      rawTransaction: '0x${hex.encode(rawTransaction)}',
      transactionHash: '0x${hex.encode(keccak(rawTransaction))}',
    );
  }

  /// Accepts a transaction and returns a signed transaction.
  Future<SignedTransaction> sign({
    int? nonce,
    BigInt? gasPrice,
    required BigInt gasLimit,
    required String to,
    BigInt? value,
    String? input,
    int? chainId,
  }) async {
    nonce ??= (await client.getTransactionCount(address)).toInt();
    gasPrice ??= await client.gasPrice();
    value ??= BigInt.zero;
    input ??= '';
    chainId ??= await client.chainId();
    return signTransaction(
      Transaction(
        nonce: nonce,
        gasPrice: gasPrice,
        gasLimit: gasLimit,
        to: to,
        value: value,
        input: input,
        chainId: chainId,
      ),
    );
  }

  Future<void> sendTransaction(SignedTransaction signedTransaction) {
    return sendRawTransaction(signedTransaction.rawTransaction);
  }

  /// Sends a Raw Signed Transaction and returns a Transaction Hash
  Future<void> sendRawTransaction(String data) async {
    final response = await client.sendRawTransaction(data);
    debugPrint(response);
  }

  /// Takes a message and does the following
  /// 1. RLP Encodes the message
  /// 2. Applies a Keccak256 hash to it
  @visibleForTesting
  Uint8List encode(Transaction transaction) {
    List<dynamic> data = [
      transaction.nonce,
      transaction.gasPrice,
      transaction.gasLimit,
      transaction.to,
      transaction.value,
      transaction.input.isEmpty ? 0 : transaction.input,
      transaction.chainId,
      0,
      0
    ].map((e) => BigInt.parse(e.toString())).toList();
    return keccak(Rlp.encode(data));
  }

  /// https://github.com/web3j/web3j/blob/c0b7b9c2769a466215d416696021aa75127c2ff1/crypto/src/main/java/org/web3j/crypto/Sign.java#L129
  BigInt? _recoverFromSignature(
    int recoveryId,
    BigInt r,
    BigInt s,
    Uint8List hash,
    ECDomainParameters parameters,
  ) {
    BigInt n = parameters.n;
    BigInt i = BigInt.from(recoveryId ~/ 2);
    BigInt x = r + (i * n);
    BigInt prime = BigInt.parse(
      '0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
    );
    if (x.compareTo(prime) >= 0) {
      // Cannot have point co-ordinates larger than this as everything takes place modulo Q.
      return null;
    }
    ECPoint R = parameters.curve.decompressPoint(recoveryId % 1, x);
    if (!(R * n)!.isInfinity) return null;

    BigInt e = decodeBigIntWithSign(1, hash);
    BigInt eI = (BigInt.zero - e) % n;
    BigInt rI = r.modInverse(n);
    BigInt srI = (rI * s) % n;
    BigInt eIrI = (rI * eI) % n;

    final q = (parameters.G * eIrI)! + (R * srI);

    return decodeBigIntWithSign(1, q!.getEncoded(false).sublist(1));
  }

  static BigInt _getPublicKey(
    BigInt privateKey,
    ECDomainParameters parameters,
  ) {
    ECPoint point = (parameters.G * privateKey)!;
    return decodeBigIntWithSign(1, point.getEncoded(false).sublist(1));
  }

  Future<BigInt> estimateGas({
    BigInt? nonce,
    BigInt? gasPrice,
    required BigInt gasLimit,
    required String to,
    BigInt? value,
    String? input,
    int? chainId = 1,
  }) async {
    nonce ??= await client.getTransactionCount(address);
    gasPrice ??= await client.gasPrice();
    value ??= BigInt.zero;
    input ??= '';
    chainId ??= await client.chainId();
    Transaction transaction = Transaction(
      nonce: nonce.toInt(),
      gasPrice: gasPrice,
      gasLimit: gasLimit,
      to: to,
      value: value,
      input: input,
      chainId: chainId,
    );
    return client.estimateGas(transaction);
  }

  static String _getAddress(BigInt privateKey) {
    BigInt publicKey = _getPublicKey(privateKey, ECCurve_secp256k1());
    return '0x${hex.encode(keccak(encodeBigInt(publicKey))).substring(24)}';
  }

  String generateMnemonic() => (bip39.generateMnemonic());
}
