import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_product_app/main.dart';
import 'package:my_product_app/firebase_options.dart';

void main() {
  test('Product app and page have the expected widget types', () {
    expect(const ProductApp(), isA<StatelessWidget>());
    expect(const ProductPage(), isA<StatefulWidget>());
  });

  test('Android Firebase configuration points to the class project', () {
    final options = DefaultFirebaseOptions.android;
    expect(options.projectId, 'my-product-app-9b3e8');
    expect(options.appId, isNotEmpty);
  });
}
