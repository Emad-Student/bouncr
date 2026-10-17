/// Route paths. Register is nested under login so Back returns to login.
class Routes {
  Routes._();

  static const home = '/';
  static const login = '/login';
  static const register = '/login/register';
  static const newEvent = '/events/new';

  static String event(String id) => '/events/$id';
  static String editEvent(String id) => '/events/$id/edit';
}
