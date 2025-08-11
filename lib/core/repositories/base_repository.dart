abstract class BaseRepository<T> {
  Future<List<T>> getAll();
  Future<T> add(T item);
  Future<void> update(T item);
  Future<void> delete(String id);
}
