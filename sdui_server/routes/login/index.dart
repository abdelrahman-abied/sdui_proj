import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/sdui_actions.dart';
import 'package:sdui_server/sdui_builder.dart';

Response onRequest(RequestContext context) {
  final page = VerticalStack(
    children: [
      SDUIContainer(
        padding: 32,
        children: [
          SDUIText(
            text: 'Welcome Back',
            style: 'title',
            color: '#1a1a2e',
          ),
        ],
      ),
      SDUIContainer(
        padding: 16,
        children: [
          InputText(
            id: 'username',
            label: 'Email Address',
            placeholder: 'you@company.com',
          ),
          InputText(
            id: 'password',
            label: 'Password',
            placeholder: '••••••••',
          ),
          ButtonPrimary(
            label: 'Sign In',
            action: sduiAction(
              type: 'form_submit',
              url: '/auth/login',
            ),
          ),
        ],
      ),
    ],
  );

  return Response.json(body: page.toJson());
}
