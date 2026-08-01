# Va de Rumba — Gestión de conciertos

App multiplataforma para iPhone y Android.

## V1
- Calendario mensual
- Crear, editar y eliminar conciertos
- Fecha, hora, lugar, precio, comentarios y estado
- Diseño pensado para Va de Rumba
- Arquitectura preparada para sincronización con Firebase

## Ejecutar
1. Instala Flutter.
2. Ejecuta `flutter pub get`.
3. Ejecuta `flutter run`.

## Sincronización entre los 5 miembros
El proyecto deja preparada la capa de datos para conectar Firebase/Cloud Firestore.
Para producción habrá que crear el proyecto Firebase, configurar iOS/Android y añadir las credenciales de Firebase.

La app actualmente usa almacenamiento local para poder probar la interfaz inmediatamente.
