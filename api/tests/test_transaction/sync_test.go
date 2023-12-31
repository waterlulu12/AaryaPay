package test_transaction

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"main/core"
	"main/endpoints/sync"
	"main/payloads"
	. "main/tests/helpers"
	test "main/tests/helpers"
	"net/http"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func TestSubmitTransaction(t *testing.T) {
	r, c, w := TestInit()

	submitController := sync.SyncController{}

	receiver := test.CreateUserWithKeyPair(t, c)
	sender := test.CreateUserWithKeyPair(t, c)

	beforeReceiverBalance := 0.0
	beforeSenderBalance := 0.0
	core.DB.QueryRow(context.Background(), "SELECT balance FROM Accounts WHERE id = $1", receiver.UserId).Scan(&beforeReceiverBalance)
	core.DB.QueryRow(context.Background(), "SELECT balance FROM Accounts WHERE id = $1", sender.UserId).Scan(&beforeSenderBalance)

	testBKVC := payloads.BalanceKeyVerificationCertificate{
		UserID:           sender.UserId,
		AvailableBalance: 100,
		PublicKey:        [32]byte(sender.KeyPair.PublicKey()),
		TimeStamp:        time.Now(),
	}

	testBKVC.Sign(c)

	testTransaction := payloads.TransactionAuthorizationMessage{
		Amount:    85,
		To:        receiver.UserId,
		BKVC:      testBKVC,
		TimeStamp: time.Now(),
	}

	testTransaction.Sign(c, sender.KeyPair.PrivateKey())

	r.POST("/v1/sync", submitController.Sync)

	// Make a test request to log in the user.
	requestBody := url.Values{}
	// requestBody.Set("transactions", base64.StdEncoding.EncodeToString(testTransaction.ToBytes(c)))

	var payload = gin.H{
		"data": []string{base64.StdEncoding.EncodeToString(testTransaction.ToBytes(c)), base64.StdEncoding.EncodeToString(testTransaction.ToBytes(c))},
	}

	jsonData, err := json.Marshal(payload)

	assert.Equal(t, nil, err)

	requestBody.Set("transactions", string(jsonData))

	req, err := http.NewRequest("POST", "/v1/sync", strings.NewReader(requestBody.Encode()))
	if err != nil {
		t.Fatalf("failed to create test request: %v", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	r.ServeHTTP(w, req)

	// Check that the response status code is as expected.
	assert.Equal(t, http.StatusAccepted, w.Code)

	afterReceiverBalance := 0.0
	afterSenderBalance := 0.0
	core.DB.QueryRow(context.Background(), "SELECT balance FROM Accounts WHERE id = $1", receiver.UserId).Scan(&afterReceiverBalance)
	core.DB.QueryRow(context.Background(), "SELECT balance FROM Accounts WHERE id = $1", sender.UserId).Scan(&afterSenderBalance)

	assert.Equal(t, beforeReceiverBalance+85, afterReceiverBalance)
	assert.Equal(t, beforeSenderBalance-85, afterSenderBalance)
}
