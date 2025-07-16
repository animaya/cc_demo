class MessageStreamConsumer {
    constructor() {
        this.eventSource = null;
        this.isConnected = false;
        this.messageCount = 0;
        this.connectionStartTime = null;
        
        this.initializeElements();
        this.bindEvents();
        this.updateConnectionTime();
    }

    initializeElements() {
        this.statusDot = document.getElementById('statusDot');
        this.statusText = document.getElementById('statusText');
        this.messageCountEl = document.getElementById('messageCount');
        this.connectionTimeEl = document.getElementById('connectionTime');
        this.messagesContainer = document.getElementById('messages');
        this.noMessagesEl = document.getElementById('noMessages');
        this.connectBtn = document.getElementById('connectBtn');
        this.clearBtn = document.getElementById('clearBtn');
    }

    bindEvents() {
        this.connectBtn.addEventListener('click', () => {
            if (this.isConnected) {
                this.disconnect();
            } else {
                this.connect();
            }
        });

        this.clearBtn.addEventListener('click', () => {
            this.clearMessages();
        });

        // Auto-reconnect on page visibility change
        document.addEventListener('visibilitychange', () => {
            if (!document.hidden && !this.isConnected) {
                // Attempt to reconnect after 1 second when page becomes visible
                setTimeout(() => {
                    if (!this.isConnected) {
                        this.connect();
                    }
                }, 1000);
            }
        });
    }

    connect() {
        if (this.isConnected) return;

        try {
            this.eventSource = new EventSource('http://127.0.0.1:8000/stream_message');
            
            this.eventSource.onopen = () => {
                this.onConnectionOpen();
            };

            this.eventSource.onmessage = (event) => {
                this.onMessage(event);
            };

            this.eventSource.onerror = (error) => {
                this.onConnectionError(error);
            };

            this.updateStatus('Connecting...', false);
            this.connectBtn.disabled = true;

        } catch (error) {
            console.error('Failed to create EventSource:', error);
            this.updateStatus('Connection Failed', false);
            this.connectBtn.disabled = false;
        }
    }

    disconnect() {
        if (this.eventSource) {
            this.eventSource.close();
            this.eventSource = null;
        }
        
        this.isConnected = false;
        this.connectionStartTime = null;
        this.updateStatus('Disconnected', false);
        this.connectBtn.textContent = 'Connect';
        this.connectBtn.disabled = false;
    }

    onConnectionOpen() {
        this.isConnected = true;
        this.connectionStartTime = new Date();
        this.updateStatus('Connected', true);
        this.connectBtn.textContent = 'Disconnect';
        this.connectBtn.disabled = false;
        this.hideNoMessages();
        
        console.log('Connected to message stream');
    }

    onMessage(event) {
        try {
            const data = JSON.parse(event.data);
            this.addMessage(data);
            this.messageCount++;
            this.updateMessageCount();
        } catch (error) {
            console.error('Failed to parse message:', error);
        }
    }

    onConnectionError(error) {
        console.error('EventSource error:', error);
        
        if (this.eventSource && this.eventSource.readyState === EventSource.CLOSED) {
            this.isConnected = false;
            this.updateStatus('Connection Lost', false);
            this.connectBtn.textContent = 'Reconnect';
            this.connectBtn.disabled = false;
            
            // Auto-reconnect after 3 seconds
            setTimeout(() => {
                if (!this.isConnected) {
                    this.connect();
                }
            }, 3000);
        }
    }

    addMessage(messageData) {
        const messageEl = document.createElement('div');
        messageEl.className = 'message';
        
        messageEl.innerHTML = `
            <div class="message-header">
                <span class="message-id">#${messageData.id}</span>
                <span class="message-time">${this.formatTime(messageData.timestamp)}</span>
            </div>
            <div class="message-text">${this.escapeHtml(messageData.message)}</div>
        `;

        this.messagesContainer.appendChild(messageEl);
        this.scrollToBottom();
    }

    formatTime(timestamp) {
        const date = new Date(timestamp);
        return date.toLocaleTimeString();
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    scrollToBottom() {
        const container = this.messagesContainer.parentElement;
        container.scrollTop = container.scrollHeight;
    }

    updateStatus(text, connected) {
        this.statusText.textContent = text;
        
        if (connected) {
            this.statusDot.classList.add('connected');
        } else {
            this.statusDot.classList.remove('connected');
        }
    }

    updateMessageCount() {
        this.messageCountEl.textContent = this.messageCount;
    }

    updateConnectionTime() {
        if (this.connectionStartTime) {
            const now = new Date();
            const diff = Math.floor((now - this.connectionStartTime) / 1000);
            const minutes = Math.floor(diff / 60);
            const seconds = diff % 60;
            this.connectionTimeEl.textContent = `${minutes}:${seconds.toString().padStart(2, '0')}`;
        } else {
            this.connectionTimeEl.textContent = '--';
        }

        // Update every second
        setTimeout(() => this.updateConnectionTime(), 1000);
    }

    clearMessages() {
        this.messagesContainer.innerHTML = '';
        this.messageCount = 0;
        this.updateMessageCount();
        
        if (!this.isConnected) {
            this.showNoMessages();
        }
    }

    hideNoMessages() {
        this.noMessagesEl.style.display = 'none';
        this.messagesContainer.style.display = 'flex';
    }

    showNoMessages() {
        this.noMessagesEl.style.display = 'flex';
        this.messagesContainer.style.display = 'none';
    }
}

// Initialize the consumer when the page loads
document.addEventListener('DOMContentLoaded', () => {
    new MessageStreamConsumer();
});