import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:mobile_dapp/transaction_tester.dart';
import 'package:walletconnect_dart/walletconnect_dart.dart';
import 'package:web3dart/src/crypto/secp256k1.dart';
import 'package:web3dart/web3dart.dart';

class WalletConnectEthereumCredentials extends CustomTransactionSender {
  WalletConnectEthereumCredentials({required this.provider});

  final EthereumWalletConnectProvider provider;

  @override
  Future<EthereumAddress> extractAddress() {
    // TODO: implement extractAddress
    throw UnimplementedError();
  }

  @override
  Future<String> sendTransaction(Transaction transaction) async {
    final hash = await provider.sendTransaction(
      from: transaction.from!.hex,
      to: transaction.to?.hex,
      data: transaction.data,
      gas: transaction.maxGas,
      gasPrice: transaction.gasPrice?.getInWei,
      value: transaction.value?.getInWei,
      nonce: transaction.nonce,
    );

    return hash;
  }

  @override
  Future<MsgSignature> signToSignature(Uint8List payload,
      {int? chainId, bool isEIP1559 = false}) {
    // TODO: implement signToSignature
    throw UnimplementedError();
  }

  @override
  // TODO: implement address
  EthereumAddress get address => throw UnimplementedError();

  @override
  MsgSignature signToEcSignature(Uint8List payload,
      {int? chainId, bool isEIP1559 = false}) {
    // TODO: implement signToEcSignature
    throw UnimplementedError();
  }
}

class EthereumTransactionTester extends TransactionTester {
  final Web3Client ethereum;
  final EthereumWalletConnectProvider provider;

  EthereumTransactionTester._internal({
    required WalletConnect connector,
    required this.ethereum,
    required this.provider,
  }) : super(connector: connector);

  factory EthereumTransactionTester() {
    // final ethereum =
    //     Web3Client('https://polygon-testnet.public.blastapi.io', Client());
    final ethereum = Web3Client('https://ropsten.infura.io/', Client());

    final connector = WalletConnect(
      bridge: 'https://bridge.walletconnect.org',
      clientMeta: PeerMeta(
        name: 'WalletConnect',
        description: 'WalletConnect Developer App',
        url: 'https://walletconnect.org',
        icons: [
          'https://gblobscdn.gitbook.com/spaces%2F-LJJeCjcLrr53DcT1Ml7%2Favatar.png?alt=media'
        ],
      ),
    );
    connector.on('connect', (session) => print(session));
    connector.on('session_request', (payload) => print(payload));
    connector.on('disconnect', (session) => print(session));

    final provider = EthereumWalletConnectProvider(connector, chainId: 80001);

    return EthereumTransactionTester._internal(
      connector: connector,
      ethereum: ethereum,
      provider: provider,
    );
  }

  @override
  Future<SessionStatus> connect({OnDisplayUriCallback? onDisplayUri}) async {
    return connector.connect(chainId: 80001, onDisplayUri: onDisplayUri);
  }

  @override
  Future<void> disconnect() async {
    await connector.killSession();
  }

  @override
  Future<String> signTransaction(SessionStatus session) async {
    final sender = EthereumAddress.fromHex(session.accounts[0]);

    // final transaction = Transaction(
    //   to: sender,
    //   from: sender,
    //   gasPrice: EtherAmount.inWei(BigInt.from(300000)),
    //   maxGas: 1000000000,
    //   value: EtherAmount.fromUnitAndValue(EtherUnit.ether, 1),
    // );
    connector.reconnect();

    final transaction = Transaction(
      to: sender,
      from: sender,
      gasPrice: EtherAmount.fromInt(EtherUnit.gwei, 10),
      maxGas: 100000,
      value: EtherAmount.fromInt(EtherUnit.finney, 1),
    );

    final credentials = WalletConnectEthereumCredentials(provider: provider);

    // Sign the transaction
    final txBytes = await ethereum.sendTransaction(credentials, transaction,
        chainId: 80001);

    // Kill the session
    connector.killSession();

    return txBytes;
  }

  @override
  Future<String> signTransactions(SessionStatus session) {
    // TODO: implement signTransactions
    throw UnimplementedError();
  }
}
