import 'package:flutter_test/flutter_test.dart';
import 'package:giveflow/donation.dart';

void main(){
  const run=bool.fromEnvironment('RUN_LOCAL_API');
  test('Flutter HTTP adapter completes a real FastAPI donation',()async{
    final api=ApiGateway('http://127.0.0.1:8021');
    const request=DonationRequest('contract_success','learning',1234);
    final receipt=await api.submit(request,'success');
    expect(receipt.amountCents,1234);expect(receipt.status,'succeeded');
    expect((await api.submit(request,'success')).id,receipt.id);
  },skip:!run);
  test('Flutter adapter reconciles real API timeout without duplicate',()async{
    final api=ApiGateway('http://127.0.0.1:8021');
    const request=DonationRequest('contract_timeout','coast',2000);
    await expectLater(()=>api.submit(request,'timeout'),throwsA(isA<PaymentUncertain>()));
    final receipt=await api.lookup(request.key);expect(receipt!.status,'succeeded');
    expect((await api.history()).where((r)=>r.key==request.key).length,1);
  },skip:!run);
}
