/******************************************************************************
 * Copyright © 2013-2021 The Komodo Platform Developers.                      *
 *                                                                            *
 * See the AUTHORS, DEVELOPER-AGREEMENT and LICENSE files at                  *
 * the top-level directory of this distribution for the individual copyright  *
 * holder information and the developer policies on copyright and licensing.  *
 *                                                                            *
 * Unless otherwise agreed in a custom licensing agreement, no part of the    *
 * Komodo Platform software, including this file may be copied, modified,     *
 * propagated or distributed except according to the terms contained in the   *
 * LICENSE file                                                               *
 *                                                                            *
 * Removal or modification of this copyright notice is prohibited.            *
 *                                                                            *
 ******************************************************************************/

#pragma once

//! Qt
#include <QSortFilterProxyModel>

//! Deps
#include <antara/gaming/ecs/system.manager.hpp>

namespace atomic_dex
{
    class portfolio_proxy_model final : public QSortFilterProxyModel
    {
        Q_OBJECT

        QString m_excluded_coin{""};
        bool    am_i_a_market_selector{false};

        bool                     m_with_balance{false};      // Tells if the proxy should filter only coins with a balance over than 0.
        bool                     m_with_fiat_balance{false}; // Tells if the proxy should filter only coins with a fiat equivalent over than 0.
        ag::ecs::system_manager& m_system_mgr;

      public:
        //! Constructor
        portfolio_proxy_model(ag::ecs::system_manager& system_manager, QObject* parent);

        //! Destructor
        ~portfolio_proxy_model()  final = default;

        void set_excluded_coin(const QString& ticker);
        void is_a_market_selector(bool is_market_selector) ;
        void reset();
        void set_with_fiat_balance(bool value) ;

        // QML API
        Q_INVOKABLE void sort_by_name(bool is_ascending);
        Q_INVOKABLE void sort_by_currency_balance(bool is_ascending);
        Q_INVOKABLE void sort_by_change_last24h(bool is_ascending);
        Q_INVOKABLE void sort_by_currency_unit(bool is_ascending);
        Q_INVOKABLE QVariantMap get(int row);

        // QML API Properties
      private:
        Q_PROPERTY(bool with_balance WRITE set_with_balance READ get_with_balance NOTIFY with_balanceChanged)
        [[nodiscard]] bool get_with_balance() const ;
        void               set_with_balance(bool value) ;

      signals:
        void with_balanceChanged();

      protected:
        // QSortFilterProxyModel functions
        [[nodiscard]] bool lessThan(const QModelIndex& source_left, const QModelIndex& source_right) const final;
        [[nodiscard]] bool filterAcceptsRow(int source_row, const QModelIndex& source_parent) const override;
    };
} // namespace atomic_dex
