// multiple clients may read simultaneously
// but write access is exclusive
// writers are favoured over readers
class ReadWriteMutex : boost::noncopyable
{
public:
    ReadWriteMutex() :
        m_readers(0),
        m_pendingWriters(0),
        m_currentWriter(false)
    {}

    // local class has access to ReadWriteMutex private members, as required
    class ScopedReadLock : boost::noncopyable
    {
    public:
        ScopedReadLock(ReadWriteMutex& rwLock) :
            m_rwLock(rwLock)
        {
            m_rwLock.acquireReadLock();
        }

        ~ScopedReadLock()
        {
            m_rwLock.releaseReadLock();
        }

    private:
        ReadWriteMutex& m_rwLock;
    };

    class ScopedWriteLock : boost::noncopyable
    {
    public:
        ScopedWriteLock(ReadWriteMutex& rwLock) :
            m_rwLock(rwLock)
        {
            m_rwLock.acquireWriteLock();
        }

        ~ScopedWriteLock()
        {
            m_rwLock.releaseWriteLock();
        }

    private:
        ReadWriteMutex& m_rwLock;
    };


private: // data
    boost::mutex m_mutex;

    unsigned int m_readers;
    boost::condition m_noReaders;

    unsigned int m_pendingWriters;
    bool m_currentWriter;
    boost::condition m_writerFinished;


private: // internal locking functions
    void acquireReadLock()
    {
        boost::mutex::scoped_lock lock(m_mutex);

        // require a while loop here, since when the writerFinished condition is notified
        // we should not allow readers to lock if there is a writer waiting
        // if there is a writer waiting, we continue waiting
        while(m_pendingWriters != 0 || m_currentWriter)
        {
            m_writerFinished.wait(lock);
        }
        ++m_readers;
    }

    void releaseReadLock()
    {
        boost::mutex::scoped_lock lock(m_mutex);
        --m_readers;

        if(m_readers == 0)
        {
            // must notify_all here, since if there are multiple waiting writers
            // they should all be woken (they continue to acquire the lock exclusively though)
            m_noReaders.notify_all();
        }
    }

    // this function is currently not exception-safe:
    // if the wait calls throw, m_pendingWriter can be left in an inconsistent state
    void acquireWriteLock()
    {
        boost::mutex::scoped_lock lock(m_mutex);

        // ensure subsequent readers block
        ++m_pendingWriters;
        
        // ensure all reader locks are released
        while(m_readers > 0)
        {
            m_noReaders.wait(lock);
        }

        // only continue when the current writer has finished 
        // and another writer has not been woken first
        while(m_currentWriter)
        {
            m_writerFinished.wait(lock);
        }
        --m_pendingWriters;
        m_currentWriter = true;
    }

    void releaseWriteLock()
    {        
        boost::mutex::scoped_lock lock(m_mutex);
        m_currentWriter = false;
        m_writerFinished.notify_all();
    }
};


// Read more: http://www.paulbridger.com/read_write_lock/#ixzz2L7gPXyPM

