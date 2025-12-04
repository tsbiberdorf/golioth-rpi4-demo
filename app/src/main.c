/*
 * Copyright (c) 2024 Golioth, Inc.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <golioth/client.h>
#include <samples/common/sample_credentials.h>

LOG_MODULE_REGISTER(golioth_demo, LOG_LEVEL_DBG);

static struct golioth_client *client;
K_SEM_DEFINE(connected_sem, 0, 1);

static void on_client_event(struct golioth_client *client,
                            enum golioth_client_event event,
                            void *arg)
{
    switch (event) {
    case GOLIOTH_CLIENT_EVENT_CONNECTED:
        LOG_INF("Golioth client connected!");
        k_sem_give(&connected_sem);
        break;
    case GOLIOTH_CLIENT_EVENT_DISCONNECTED:
        LOG_WRN("Golioth client disconnected");
        break;
    default:
        break;
    }
}

int main(void)
{
    int err;
    int counter = 0;

    LOG_INF("Golioth RPi4 Demo Starting");
    LOG_INF("Zephyr version: %s", KERNEL_VERSION_STRING);

    /* Initialize Golioth client */
    client = golioth_client_create(&(struct golioth_client_config){
        .credentials = {
            .auth_type = GOLIOTH_TLS_AUTH_TYPE_PSK,
            .psk = {
                .psk_id = CONFIG_GOLIOTH_SAMPLE_PSK_ID,
                .psk_id_len = sizeof(CONFIG_GOLIOTH_SAMPLE_PSK_ID) - 1,
                .psk = CONFIG_GOLIOTH_SAMPLE_PSK,
                .psk_len = sizeof(CONFIG_GOLIOTH_SAMPLE_PSK) - 1,
            },
        },
    });

    if (!client) {
        LOG_ERR("Failed to create Golioth client");
        return -1;
    }

    /* Register event callback */
    err = golioth_client_register_event_callback(client, on_client_event, NULL);
    if (err) {
        LOG_ERR("Failed to register event callback: %d", err);
        return err;
    }

    /* Start the client */
    err = golioth_client_start(client);
    if (err) {
        LOG_ERR("Failed to start Golioth client: %d", err);
        return err;
    }

    /* Wait for connection */
    LOG_INF("Waiting for connection to Golioth...");
    k_sem_take(&connected_sem, K_FOREVER);

    /* Main loop - send periodic hello messages */
    while (true) {
        LOG_INF("Hello from RPi4! Counter: %d", counter);

        /* Example: Set a LightDB State value */
        char buf[32];
        snprintf(buf, sizeof(buf), "%d", counter);
        
        err = golioth_lightdb_set_sync(client,
                                       GOLIOTH_LIGHTDB_STATE_PATH("counter"),
                                       GOLIOTH_CONTENT_TYPE_JSON,
                                       buf,
                                       strlen(buf),
                                       K_SECONDS(5));
        if (err) {
            LOG_WRN("Failed to set counter: %d", err);
        } else {
            LOG_DBG("Counter updated in LightDB State");
        }

        counter++;
        k_sleep(K_SECONDS(10));
    }

    return 0;
}
