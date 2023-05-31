import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:mobile_dapp/algorand_transaction_tester.dart';
import 'package:mobile_dapp/ethereum_transaction_tester.dart';
import 'package:mobile_dapp/transaction_tester.dart';
import 'package:mobile_dapp/wallet_connect_lifecycle.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:walletconnect_dart/walletconnect_dart.dart';

void main() {
  runApp(const MyApp());
}

enum NetworkType {
  ethereum,
  algorand,
}

enum TransactionState {
  disconnected,
  connecting,
  connected,
  connectionFailed,
  transferring,
  success,
  failed,
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile dApp',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'WalletConnect'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String txId = '';
  String _displayUri = '';

  static const _networks = ['Ethereum (Ropsten)', 'Algorand (Testnet)'];
  NetworkType? _network = NetworkType.ethereum;
  TransactionState _state = TransactionState.disconnected;
  TransactionTester? _transactionTester = EthereumTransactionTester();

  SessionStatus? mysession;
  String? metamaskUri;

  @override
  Widget build(BuildContext context) {
    return WalletConnectLifecycle(
      connector: _transactionTester!.connector,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('Select network: ',
                        style: Theme.of(context).textTheme.headline6),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DropdownButton(
                      value: _networks[_network!.index],
                      items: _networks
                          .map(
                            (value) => DropdownMenuItem(
                                value: value, child: Text(value)),
                          )
                          .toList(),
                      onChanged: _changeNetworks),
                ),
              ],
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // (_displayUri.isEmpty)
                  //     ? Padding(
                  //         padding: const EdgeInsets.only(
                  //           left: 16,
                  //           right: 16,
                  //           bottom: 16,
                  //         ),
                  //         child: Text(
                  //           'Click on the button below to transfer ${_network == NetworkType.ethereum ? '0.0001 Eth from Ethereum' : '0.0001 Algo from the Algorand'} account connected through WalletConnect to the same account.',
                  //           style: Theme.of(context).textTheme.headline6,
                  //           textAlign: TextAlign.center,
                  //         ),
                  //       )
                  //     : QrImage(data: _displayUri),
                  ElevatedButton(
                    onPressed:
                        _transactionStateToAction(context, state: _state),
                    child: Text(
                      _transactionStateToString(state: _state),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Future.delayed(const Duration(seconds: 1), () async {
                        try {
                          await launchUrlString(metamaskUri!,
                              mode: LaunchMode.externalApplication);
                          final result = await _transactionTester
                              ?.signTransaction(mysession!);
                          print(result);
                          setState(() => _state = TransactionState.success);
                        } catch (e) {
                          print('Transaction error: $e');
                          setState(() => _state = TransactionState.failed);
                        }
                      });
                    },
                    child: Text(
                      '交易',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await launchUrlString(metamaskUri!,
                          mode: LaunchMode.externalApplication);
                    },
                    child: Text(
                      '跳转',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _transactionTester?.disconnect();
                    },
                    child: Text(
                      'Close',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeNetworks(String? network) {
    if (network == null) return null;
    final newNetworkIndex = _networks.indexOf(network);
    final newNetwork = NetworkType.values[newNetworkIndex];

    switch (newNetwork) {
      case NetworkType.algorand:
        _transactionTester = AlgorandTransactionTester();
        break;
      case NetworkType.ethereum:
        _transactionTester = EthereumTransactionTester();
        break;
    }

    setState(
      () => _network = newNetwork,
    );
  }

  String _transactionStateToString({required TransactionState state}) {
    switch (state) {
      case TransactionState.disconnected:
        return 'Connect!';
      case TransactionState.connecting:
        return 'Connecting';
      case TransactionState.connected:
        return 'Session connected, preparing transaction...';
      case TransactionState.connectionFailed:
        return 'Connection failed';
      case TransactionState.transferring:
        return 'Transaction in progress...';
      case TransactionState.success:
        return 'Transaction successful';
      case TransactionState.failed:
        return 'Transaction failed';
    }
  }

  VoidCallback? _transactionStateToAction(BuildContext context,
      {required TransactionState state}) {
    switch (state) {
      // Progress, action disabled
      case TransactionState.connecting:
      case TransactionState.transferring:
      case TransactionState.connected:
        return null;

      // Initiate the connection
      case TransactionState.disconnected:
      case TransactionState.connectionFailed:
        return () async {
          setState(() => _state = TransactionState.connecting);
          final session =
              await _transactionTester?.connect(onDisplayUri: (uri) async {
            metamaskUri = uri.split('bridge.walletconnect.org').first +
                'bridge.walletconnect.org';
            print('full uri:$uri ,launchUri: $metamaskUri');
            metamaskUri = 'metamask://';
            if (await canLaunchUrlString('metamask://')) {
              launchUrlString(uri, mode: LaunchMode.externalApplication);
            } else {
              showDialog(
                  context: context,
                  builder: (buildContext) {
                    return AlertDialog(
                      title: Text('提示'),
                      content: Text('没有安装metamask'),
                      actions: [
                        ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text('确定'))
                      ],
                    );
                  });
            }

            setState(() {
              _displayUri = uri;
            });
          });
          if (session?.chainId != 80001) {
            showDialog(
                context: context,
                builder: (buildContext) {
                  return AlertDialog(
                    title: Text('提示'),
                    content: Text('请在matamask上切换到polygon网络'),
                    actions: [
                      ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('确定'))
                    ],
                  );
                });
          }
          mysession = session;
          // if (session == null) {
          //   print('Unable to connect');
          //   setState(() => _state = TransactionState.failed);
          //   return;
          // }

          // setState(() => _state = TransactionState.connected);
          // Future.delayed(const Duration(seconds: 1), () async {
          //   // Initiate the transaction
          //   setState(() => _state = TransactionState.transferring);

          //   try {
          //     await _transactionTester?.signTransaction(session);
          //     setState(() => _state = TransactionState.success);
          //   } catch (e) {
          //     print('Transaction error: $e');
          //     setState(() => _state = TransactionState.failed);
          //   }
          // });
        };

      // Finished
      case TransactionState.success:
      case TransactionState.failed:
        return null;
    }
  }
}
