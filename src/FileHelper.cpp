/*
 * Copyright (C) 2026 - Timo Könnecke <github.com/moWerk>
 *               2025 - Ed Beroset <beroset@ieee.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 2.1 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "FileHelper.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QTextStream>
#include <QDebug>

static const QString dataPath = QStringLiteral("/home/ceres/.local/share/asteroid-shopper/");

QString FileHelper::listPath(const QString &listName)
{
    return dataPath + listName + "-shopper.txt";
}

bool FileHelper::exists(const QString &listName)
{
    return QFileInfo::exists(listPath(listName));
}

QString FileHelper::readFile(const QString &listName)
{
    QString path = listPath(listName);
    QFileInfo info(path);
    if (!info.isFile()) {
        qDebug() << "Reading list \"" << listName << "\" DENIED: not a regular file";
        return QString();
    }
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qDebug() << "Reading list \"" << listName << "\" FAILED:" << file.errorString();
        return QString();
    }
    QTextStream in(&file);
    QString content = in.readAll();
    file.close();
    return content;
}

bool FileHelper::writeFile(const QString &listName, const QString &content)
{
    QDir().mkpath(dataPath);
    QString path = listPath(listName);
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        qDebug() << "Writing list \"" << listName << "\" FAILED:" << file.errorString();
        return false;
    }
    QTextStream out(&file);
    out << content;
    file.close();
    return true;
}
